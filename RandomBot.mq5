#property copyright "RandomBot"
#property version "1.00"

#include <Trade/Trade.mqh>

//================== INPUTS ==========================================
input double InpLot = 0.01; // Лот
input int InpSL_Pips = 200; // Stop Loss, пипсов (0 = без SL)
input int InpTP_Pips = 200; // Take Profit, пипсов (0 = без TP)

CTrade trade;

int OnInit() {
    trade.SetDeviationInPoints(20);

    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {}

void OnTick() {

   if (PositionsTotal() > 0) {
      return;
   }

   if (MathRand() % 2 == 1) {
      OpenBuy();
   } else {
      OpenSell();
   }
}

void OpenSell() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = (InpSL_Pips > 0) ? bid + InpSL_Pips * _Point : 0.0;
    double tp = (InpTP_Pips > 0) ? bid - InpTP_Pips * _Point : 0.0;
    sl = (sl > 0) ? NormalizeDouble(sl, _Digits) : 0.0;
    tp = (tp > 0) ? NormalizeDouble(tp, _Digits) : 0.0;

    if (!trade.Sell(InpLot, _Symbol, bid, sl, tp, "RandomBot SELL"))
        Print("Ошибка открытия SELL: ", trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
//| Открыть BUY                                                       |
//+------------------------------------------------------------------+
void OpenBuy() {
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = (InpSL_Pips > 0) ? ask - InpSL_Pips * _Point : 0.0;
    double tp = (InpTP_Pips > 0) ? ask + InpTP_Pips * _Point : 0.0;
    sl = (sl > 0) ? NormalizeDouble(sl, _Digits) : 0.0;
    tp = (tp > 0) ? NormalizeDouble(tp, _Digits) : 0.0;

    if (!trade.Buy(InpLot, _Symbol, ask, sl, tp, "RandomBot BUY"))
        Print("Ошибка открытия BUY: ", trade.ResultRetcodeDescription());
}
