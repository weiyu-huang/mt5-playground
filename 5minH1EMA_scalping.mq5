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
input int MagicNumber = 80000002;                         // EA unique identifier

input group "Optimization Parameters"
input ENUM_TIMEFRAMES CurrentTimeFrame = PERIOD_M5;       // Current time period
input int CurrentFastMaPeriod = 8;                        // Current fast line
input int CurrentMidMaPeriod = 13;                        // Current mid line
input int CurrentSlowMaPeriod = 21;                       // Current slow line

input ENUM_TIMEFRAMES TrendMaTimeFrame = PERIOD_H1;       // Macro trend time period
input int TrendFastMaPeriod = 8;                          // Macro trend fast line
input int TrendSlowMaPeriod = 21;                         // Macro trend slow line

input group "Other Settings"
input bool inpDisplayDebugInfoScreen = true;

int currentFastMaHandle;  // current ma handle
double currentFastMaBuffer[];
int currentMidMaHandle;
double currentMidMaBuffer[];
int currentSlowMaHandle;
double currentSlowMaBuffer[];

int trendFastMaHandle;  // macro trend ma handle
double trendFastMaBuffer[];
int trendSlowMaHandle;
double trendSlowMaBuffer[];

int OnInit() {
   currentFastMaHandle = iMA(_Symbol, CurrentTimeFrame, CurrentFastMaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   currentMidMaHandle = iMA(_Symbol, CurrentTimeFrame, CurrentMidMaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   currentSlowMaHandle = iMA(_Symbol, CurrentTimeFrame, CurrentSlowMaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   trendFastMaHandle = iMA(_Symbol, TrendMaTimeFrame, TrendFastMaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   trendSlowMaHandle = iMA(_Symbol, TrendMaTimeFrame, TrendSlowMaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if (currentFastMaHandle == INVALID_HANDLE ||
       currentMidMaHandle == INVALID_HANDLE ||
       currentSlowMaHandle == INVALID_HANDLE ||
       trendFastMaHandle == INVALID_HANDLE ||
       trendSlowMaHandle == INVALID_HANDLE) {
      Print("Failed to create MA handle");
      return(INIT_FAILED);
   }

   ArrayResize(currentFastMaBuffer, 2);
   ArrayResize(currentMidMaBuffer, 2);
   ArrayResize(currentSlowMaBuffer, 2);
   ArrayResize(trendFastMaBuffer, 2);
   ArrayResize(trendSlowMaBuffer, 2);

   ArraySetAsSeries(currentFastMaBuffer, true);
   ArraySetAsSeries(currentMidMaBuffer, true);
   ArraySetAsSeries(currentSlowMaBuffer, true);
   ArraySetAsSeries(trendFastMaBuffer, true);
   ArraySetAsSeries(trendSlowMaBuffer, true);

   trade.SetExpertMagicNumber(MagicNumber);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   
}

void OnTick() {
   // run once at each bar's openPrice
   int bars = iBars(_Symbol, CurrentTimeFrame);
   static int prevBars = 0;
   if (bars == prevBars) return;
   prevBars = bars;

   CopyBuffer(currentFastMaHandle, 0, 0, 2, currentFastMaBuffer);
   CopyBuffer(currentMidMaHandle, 0, 0, 2, currentMidMaBuffer);
   CopyBuffer(currentSlowMaHandle, 0, 0, 2, currentSlowMaBuffer);
   CopyBuffer(trendFastMaHandle, 0, 0, 2, trendFastMaBuffer);
   CopyBuffer(trendSlowMaHandle, 0, 0, 2, trendSlowMaBuffer);

   int maTrend = getTrendFlag();
   int currentTrend = getCurrentTrendFlag();
   int trend = (maTrend == 1 && currentTrend == 1) ? 1 : (maTrend == -1 && currentTrend == -1) ? -1 : 0;

   if (inpDisplayDebugInfoScreen) {
      string debugInfo = StringFormat(
         "Macro Fast = %.2f\n Macro Slow = %.2f\n Macro Dir = %d\n", 
         trendFastMaBuffer[1], trendSlowMaBuffer[1], maTrend
      );
      debugInfo += StringFormat(
         "Current Fast = %.2f\n Current Mid = %.2f\n Current Slow = %.2f\n Current Dir = %d\n Dir = %d", 
         currentFastMaBuffer[1], currentMidMaBuffer[1], currentSlowMaBuffer[1], currentTrend, trend
      );
      Comment(debugInfo);
   }
}

// Current trend information
int getCurrentTrendFlag() {
   int result = 0;  // 0: no direction; 1: long; -1: short

   if (currentFastMaBuffer[1] > currentMidMaBuffer[1] && currentMidMaBuffer[1] > currentSlowMaBuffer[1]) {
      result = 1;
   } else if (currentFastMaBuffer[1] < currentMidMaBuffer[1] && currentMidMaBuffer[1] < currentSlowMaBuffer[1]) {
      result = -1;
   }

   return result;
}

// Macro trend information
int getTrendFlag() {
   int result = 0;  // 0: no direction; 1: long; -1: short
   double closePrice = iClose(_Symbol, TrendMaTimeFrame, 1);

   if (closePrice == 0.0) {
      return result;
   }

   if (trendFastMaBuffer[1] > trendSlowMaBuffer[1] && closePrice > trendSlowMaBuffer[1]) {
      result = 1;
   } else if (trendFastMaBuffer[1] < trendSlowMaBuffer[1] && closePrice < trendSlowMaBuffer[1]) {
      result = -1;
   }

   return result;
}
