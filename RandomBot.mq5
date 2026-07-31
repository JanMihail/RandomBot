#property copyright "RandomBot"
#property version "2.0"

#include <Trade/Trade.mqh>

//================== INPUTS ==========================================
input double InpLot = 0.08;                 // Лот
input int InpSL_Pips = 6000;                // Stop Loss, пипсов (0 = без SL)
input int InpTP_Pips = 200;                 // Take Profit, пипсов (0 = без TP)
input int InpLossDistanceToAvg_Pips = 3000; // Дистанция при которой усредняться, пипсов

//================== GLOBAL VARS======================================
ulong basePositionTicket;              // Номер тикета основной позиции
double basePositionOpenPrice;          // Цена открытия основной позиции
double basePositionSL;                 // SL основной позиции
ENUM_ORDER_TYPE basePositionOrderType; // Тип основной позиции

CTrade trade;

int OnInit() {
    trade.SetDeviationInPoints(20);

    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {}

void OnTick() {

    if (PositionsTotal() == 0) {
        OpenRandomPosition();
    }

    else if (PositionsTotal() == 1) {
        ManagePosition();
    }
}

void OpenRandomPosition() {
    if (MathRand() % 2 == 1) {
        BasePositionOpenBuy();
    } else {
        BasePositionOpenSell();
    }
}

void ManagePosition() {
    if (basePositionOrderType == ORDER_TYPE_BUY) {
        ManageBuyPosition();
    } else {
        ManageSellPosition();
    }
}

void ManageBuyPosition() {
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double tp = (basePositionOpenPrice + ask) / 2;
    tp = NormalizeDouble(tp, _Digits);

    if (MathAbs(basePositionOpenPrice - bid) >= InpLossDistanceToAvg_Pips * _Point) {

        bool resOpen = trade.Buy(InpLot, _Symbol, ask, basePositionSL, tp, "AvgPosition BUY");
        if (!resOpen) {
            PrintFormat("Ошибка открытия AvgPosition BUY: %s", trade.ResultRetcodeDescription());
        }

        bool resModify = trade.PositionModify(basePositionTicket, basePositionSL, tp);
        if (!resModify) {
            PrintFormat("Ошибка модицикации BasePosition BUY: %s", trade.ResultRetcodeDescription());
        }
    }
}

void ManageSellPosition() {
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double tp = (basePositionOpenPrice + bid) / 2;
    tp = NormalizeDouble(tp, _Digits);

    if (MathAbs(basePositionOpenPrice - ask) >= InpLossDistanceToAvg_Pips * _Point) {

        bool resOpen = trade.Sell(InpLot, _Symbol, bid, basePositionSL, tp, "AvgPosition SELL");
        if (!resOpen) {
            PrintFormat("Ошибка открытия AvgPosition SELL: %s", trade.ResultRetcodeDescription());
        }

        bool resModify = trade.PositionModify(basePositionTicket, basePositionSL, tp);
        if (!resModify) {
            PrintFormat("Ошибка модицикации BasePosition SELL: %s", trade.ResultRetcodeDescription());
        }
    }
}

void BasePositionOpenBuy() {
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = (InpSL_Pips > 0) ? ask - InpSL_Pips * _Point : 0.0;
    double tp = (InpTP_Pips > 0) ? ask + InpTP_Pips * _Point : 0.0;
    sl = (sl > 0) ? NormalizeDouble(sl, _Digits) : 0.0;
    tp = (tp > 0) ? NormalizeDouble(tp, _Digits) : 0.0;

    if (trade.Buy(InpLot, _Symbol, ask, sl, tp, "BasePosition BUY")) {

        basePositionTicket = trade.ResultOrder();
        basePositionOpenPrice = ask;
        basePositionSL = sl;
        basePositionOrderType = ORDER_TYPE_BUY;

        PrintFormat(
            "basePositionTicket = %G, basePositionOpenPrice = %G, basePositionOrderType = %s",
            basePositionTicket,
            basePositionTicket,
            EnumToString(basePositionOrderType)
        );
    }

    else {
        PrintFormat("Ошибка открытия BasePosition BUY: %s", trade.ResultRetcodeDescription());
    }
}

void BasePositionOpenSell() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = (InpSL_Pips > 0) ? bid + InpSL_Pips * _Point : 0.0;
    double tp = (InpTP_Pips > 0) ? bid - InpTP_Pips * _Point : 0.0;
    sl = (sl > 0) ? NormalizeDouble(sl, _Digits) : 0.0;
    tp = (tp > 0) ? NormalizeDouble(tp, _Digits) : 0.0;

    if (trade.Sell(InpLot, _Symbol, bid, sl, tp, "BasePosition SELL")) {

        basePositionTicket = trade.ResultOrder();
        basePositionOpenPrice = bid;
        basePositionSL = sl;
        basePositionOrderType = ORDER_TYPE_SELL;

        PrintFormat(
            "basePositionTicket = %G, basePositionOpenPrice = %G, basePositionOrderType = %s",
            basePositionTicket,
            basePositionTicket,
            EnumToString(basePositionOrderType)
        );
    }

    else {
        PrintFormat("Ошибка открытия BasePosition SELL: %s", trade.ResultRetcodeDescription());
    }
}

/**
 * Получить текущую плавающую прибыль/убыток по всем открытым позициям
 */
double CalculateOpenProfit(string symbol = "", long magic = -1) {
    double totalProfit = 0.0;

    // Перебираем все открытые позиции
    for (int i = 0; i < PositionsTotal(); i++) {
        // Получаем тикет позиции и одновременно выбираем её для работы
        ulong ticket = PositionGetTicket(i);

        if (ticket > 0) {
            // Фильтр по символу
            if (symbol != "" && PositionGetString(POSITION_SYMBOL) != symbol)
                continue;

            // Фильтр по Magic Number
            if (magic != -1 && PositionGetInteger(POSITION_MAGIC) != magic)
                continue;

            // Складываем чистую прибыль и своп
            double profit = PositionGetDouble(POSITION_PROFIT);
            double swap = PositionGetDouble(POSITION_SWAP);

            totalProfit += (profit + swap);
        }
    }

    return totalProfit;
}