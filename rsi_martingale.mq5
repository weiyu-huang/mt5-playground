#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Indicators\Indicator.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\SymbolInfo.mqh>

#define SECONDS_IN_A_DAY 86400

CDealInfo m_deal;
CTrade trade;
CPositionInfo positionInfo;
CSymbolInfo m_symbol;

input group "Basic Parameters"
input int MagicNumber = 80000001;  // EA unique identifier
input double InitialLot = 0.01;  // initial lot
input int MaxSpread = 10;  // max acceptable spread
input int MaxSlippage = 3;  // max acceptable slippage

input group "Optimization Parameters"
input ENUM_TIMEFRAMES Current_TimeFrame = PERIOD_M10;  // Current time period
input int RSI_Period = 14;  // RSI Period
input int RSILevel = 70;  // RSI upper bound
input int BarsForCondition = 20;  // number of k lines to compare
input int TakeProfit = 300;  // take profit points
input int StopLoss = 150;  // stop loss points
input double MartingaleMultiplier = 2;  // lot multiplier when loss

input group "Time Filters"
input int StartTime = 1;  // EA begin time
input int EndTime = 23;  // EA end time
input bool Hour_00 = false;  // disable trasaction 00:00–00:59
input bool Hour_01 = false;  // disable trasaction 01:00–01:59
input bool Hour_02 = false;  // disable trasaction 02:00–02:59
input bool Hour_03 = false;  // disable trasaction 03:00–03:59
input bool Hour_04 = false;  // disable trasaction 04:00–04:59
input bool Hour_05 = false;  // disable trasaction 05:00–05:59
input bool Hour_06 = false;  // disable trasaction 06:00–06:59
input bool Hour_07 = false;  // disable trasaction 07:00–07:59
input bool Hour_08 = false;  // disable trasaction 08:00–08:59
input bool Hour_09 = false;  // disable trasaction 09:00–09:59
input bool Hour_10 = false;  // disable trasaction 10:00–10:59
input bool Hour_11 = false;  // disable trasaction 11:00–11:59
input bool Hour_12 = false;  // disable trasaction 12:00–12:59
input bool Hour_13 = false;  // disable trasaction 13:00–13:59
input bool Hour_14 = false;  // disable trasaction 14:00–14:59
input bool Hour_15 = false;  // disable trasaction 15:00–15:59
input bool Hour_16 = false;  // disable trasaction 16:00–16:59
input bool Hour_17 = false;  // disable trasaction 17:00–17:59
input bool Hour_18 = false;  // disable trasaction 18:00–18:59
input bool Hour_19 = false;  // disable trasaction 19:00–19:59
input bool Hour_20 = false;  // disable trasaction 20:00–20:59
input bool Hour_21 = false;  // disable trasaction 21:00–21:59
input bool Hour_22 = false;  // disable trasaction 22:00–22:59
input bool Hour_23 = false;  // disable trasaction 23:00–23:59

input group "Other Settings"
input bool inpDisplayDebugInfoScreen = true;  // display debug info

int rsiHandle;
double rsiBuffer[];
bool hoursToAvoid[24];

int OnInit() {
   if (StartTime > EndTime) {
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   if (rsiHandle == INVALID_HANDLE)
   {
      Print("Failed to create RSI handle");
      return(INIT_FAILED);
   }
   
   ArrayResize(rsiBuffer, BarsForCondition + 1);
   ArraySetAsSeries(rsiBuffer, true);
   
   trade.SetExpertMagicNumber(MagicNumber);
   hoursToAvoid[0] = Hour_00;
   hoursToAvoid[1] = Hour_01;
   hoursToAvoid[2] = Hour_02;
   hoursToAvoid[3] = Hour_03;
   hoursToAvoid[4] = Hour_04;
   hoursToAvoid[5] = Hour_05;
   hoursToAvoid[6] = Hour_06;
   hoursToAvoid[7] = Hour_07;
   hoursToAvoid[8] = Hour_08;
   hoursToAvoid[9] = Hour_09;
   hoursToAvoid[10] = Hour_10;
   hoursToAvoid[11] = Hour_11;
   hoursToAvoid[12] = Hour_12;
   hoursToAvoid[13] = Hour_13;
   hoursToAvoid[14] = Hour_14;
   hoursToAvoid[15] = Hour_15;
   hoursToAvoid[16] = Hour_16;
   hoursToAvoid[17] = Hour_17;
   hoursToAvoid[18] = Hour_18;
   hoursToAvoid[19] = Hour_19;
   hoursToAvoid[20] = Hour_20;
   hoursToAvoid[21] = Hour_21;
   hoursToAvoid[22] = Hour_22;
   hoursToAvoid[23] = Hour_23;
   
   Print("Initialization done");
   Print("Martingale", MartingaleMultiplier);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   if (rsiHandle != INVALID_HANDLE) {
      IndicatorRelease(rsiHandle);
      Print("RSI handle released");
   }
}

void OnTick() {  
   // run once at each bar's openPrice
   int bars = iBars(_Symbol, Current_TimeFrame);
   static int prevBars = 0;
   if (bars == prevBars) return;
   prevBars = bars;

   if (CopyBuffer(rsiHandle, 0, 0, BarsForCondition + 1, rsiBuffer) == -1) {
      Print("Failed to copy RSI values");
      return;
   }
 
   // check last trade information
   ENUM_DEAL_TYPE closedDealType;
   double lastNegativeDealProfit;
   double lastNegativeDealLot;
   WasLastPosisionNegative(_Symbol, closedDealType, lastNegativeDealProfit, lastNegativeDealLot);
   
   if (inpDisplayDebugInfoScreen) {
      string debugInfo = StringFormat(
         "Latest RSI = %.2f\n Long = %s\n Short = %s\n Allowed = %s\n Last: %s; Profit: %s", 
         rsiBuffer[0],
         IsMinRSIForBars() ? "True" : "False",
         IsMaxRSIForBars() ? "True" : "False",
         IsTradingTimeAllowed() ? "True" : "False",
         EnumToString(closedDealType),
         DoubleToString(lastNegativeDealProfit, 2)
      );
      Comment(debugInfo);
   }
   
   // When last trade has loss, open a reverse trade, increase lot, skip the rest of logics
   if (lastNegativeDealProfit < 0) {
      if (OpenReversedPositionWithIncreasedLot(closedDealType, lastNegativeDealLot)) {
         return;
      }
   }
   
   if (!IsTradingTimeAllowed()) {
      Print("Not allow trading now");
      return;
   }
   
   double lot = LotCheck(InitialLot);
   if (lot == 0.0) {
      return;
   }
   
   double currentRSI = rsiBuffer[0];
   
   // LONG: rsi is smallest k, no long order, rsi < threshold, no loss in last trade
   if (
      IsMinRSIForBars() && 
      !hasPositionOpen(POSITION_TYPE_BUY) && 
      currentRSI < (100 - RSILevel) &&
      lastNegativeDealProfit >= 0
   ) {
      OpenBuy(lot);
   }
   
   // SHORT: rsi is largest k, no short order, rsi > threshold, no lss in last trade
   if (
      IsMaxRSIForBars() && 
      !hasPositionOpen(POSITION_TYPE_SELL) && 
      currentRSI > RSILevel &&
      lastNegativeDealProfit >= 0
   ) {
      OpenSell(lot);
   }
   
   // OUT
   if (lastNegativeDealProfit >= 0) {
      if (hasPositionOpen(POSITION_TYPE_BUY) && currentRSI > RSILevel) {
         ClosePosition(POSITION_TYPE_BUY);
      }
      if (hasPositionOpen(POSITION_TYPE_SELL) && currentRSI < 100 - RSILevel) {
         ClosePosition(POSITION_TYPE_SELL);
      }
   }
}

bool OpenReversedPositionWithIncreasedLot(ENUM_DEAL_TYPE closedDealType, double lastNegativeDealLot) {
   double lot = lastNegativeDealLot * MartingaleMultiplier;
   lot = LotCheck(lot);
   if (lot == 0) {
      return false;
   }
   if (HasPositionWithSameVolumeOpen(lot)) {
      return false;
   }
   
   switch (closedDealType) {
      case DEAL_TYPE_BUY:
         OpenBuy(lot);
         return true;
      case DEAL_TYPE_SELL:
         OpenSell(lot);
         return true;
      default:
         return false;
   }
}

bool HasPositionWithSameVolumeOpen(double targetVolume) {
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      if (positionInfo.SelectByIndex(i)) {
         if (positionInfo.Volume() == targetVolume && 
             positionInfo.Magic() == MagicNumber && 
             positionInfo.Symbol() == _Symbol) {
            return true;
         }
      }
   }
   return false;
}

bool WasLastPosisionNegative(string symbol, ENUM_DEAL_TYPE &closedDealType, double &lastNegativeDealProfit, double &lastNegativeDealLot) {
   datetime start_time = TimeCurrent() - SECONDS_IN_A_DAY * 10;
   datetime end_time = TimeCurrent() + SECONDS_IN_A_DAY * 1;
   HistorySelect(start_time, end_time);
   
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--) {
       if (m_deal.SelectByIndex(i)) {
          if (m_deal.Symbol() == symbol && m_deal.Magic() == MagicNumber && m_deal.Entry() == DEAL_ENTRY_OUT) {
             lastNegativeDealProfit = m_deal.Profit();
             closedDealType = m_deal.DealType();
             lastNegativeDealLot = m_deal.Volume();
             return true;
          }
       }
    }
    return false;
}

void ClosePosition(int positionType) {
   if (positionType != POSITION_TYPE_BUY && positionType != POSITION_TYPE_SELL) {
      Print("Invalid position type. Use POSITION_TYPE_BUY or POSITION_TYPE_SELL.");
      return;
   }
   
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      if (positionInfo.SelectByIndex(i)) {
         if (positionInfo.Magic() == MagicNumber && 
             positionInfo.PositionType() == positionType && 
             positionInfo.Symbol() == _Symbol) {
            ulong ticket = positionInfo.Ticket();
            if (!trade.PositionClose(ticket)) {
               Print("Failed to close position with ticket: ", ticket);
            }
         }
      }
   }   
}

void OpenBuy(double lot) {
   double ask;
   long spread;
   
   if(!SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask) || !SymbolInfoInteger(_Symbol, SYMBOL_SPREAD, spread)) {
      Print("Cannot open order due to unable to get symbol info");
      return;
   }
   
   if (MaxSpread > 0 && spread > MaxSpread) {
      Print("Cannot open order due to too high spread");
      return;
   }
   
   double tpPrice = ask + TakeProfit * _Point;
   double slPrice = ask - StopLoss * _Point;
   
   if (!trade.Buy(lot, _Symbol, ask, slPrice, tpPrice)) {
      Print("Failed to make long order");
   }
}

void OpenSell(double lot) {
   double bid;
   long spread;
   
   if(!SymbolInfoDouble(_Symbol, SYMBOL_BID, bid) || !SymbolInfoInteger(_Symbol, SYMBOL_SPREAD, spread)) {
      Print("Cannot open order due to unable to get symbol info");
      return;
   }
   
   if (MaxSpread > 0 && spread > MaxSpread) {
      Print("Cannot open order due to too high spread");
      return;
   }
   
   double tpPrice = bid - TakeProfit * _Point;
   double slPrice = bid + StopLoss * _Point;
   
   if (!trade.Sell(lot, _Symbol, bid, slPrice, tpPrice)) {
      Print("Failed to make short order");
   }
}

bool hasPositionOpen(int positionType) {
   if (positionType != POSITION_TYPE_BUY && positionType != POSITION_TYPE_SELL) {
      Print("Invalid position type. Use POSITION_TYPE_BUY or POSITION_TYPE_SELL.");
      return false;
   }

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if (positionInfo.SelectByIndex(i)) {
         if (positionInfo.PositionType() == positionType && 
             positionInfo.Magic() == MagicNumber) {
            return true;
         }
      }
   }
   return false;
}

double LotCheck(double lots) {
    double volume = NormalizeDouble(lots, 2);
    double stepVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    
    if (stepVol > 0.0) {
        volume = stepVol * MathFloor(volume / stepVol);  
    }
    
    volume = volume < minVol ? 0.0 : MathMin(volume, maxVol);
    return volume;
}

bool IsTradingTimeAllowed() {
   MqlDateTime mqlTime;
   TimeToStruct(TimeCurrent(), mqlTime);
   int currentHour = mqlTime.hour;
   
   if (hoursToAvoid[currentHour]) {
      return false;
   }
   if (currentHour < StartTime || currentHour > EndTime) {
      return false;
   } 
   return true;
}

bool IsMinRSIForBars() {
   for (int i = 1; i <= BarsForCondition; i++) {
      if (rsiBuffer[i] < rsiBuffer[0]) {
         return false;
      }
   }
   return true;
}

bool IsMaxRSIForBars() {
   for (int i = 1; i <= BarsForCondition; i++) {
      if (rsiBuffer[i] > rsiBuffer[0]) {
         return false;
      }
   }
   return true;
}