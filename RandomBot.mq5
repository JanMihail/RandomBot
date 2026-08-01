#property copyright "RandomBot"
#property version "4.0"

#include "Structures.mqh"
#include <Trade/Trade.mqh>

//================== INPUTS ==========================================
input double InpLot = 0.08;                  // Лот
input int InpSL_Pips = 6000;                 // Stop Loss, пипсов (0 = без SL)
input int InpTP_Pips = 200;                  // Take Profit, пипсов (0 = без TP)
input int InpThresholdOneDirectionCount = 5; // >= позиций в одну сторону, закрываем всё при балансе Buy/Sell

//================== GLOBAL VARS======================================
Position basePosition; // Основная позиция. От неё строится Random
CTrade trade;          // Объект для выполнения торговых операций

int OnInit() {
    // Устанавливаем допустимое отклонение для торговли
    trade.SetDeviationInPoints(20);

    // Инициализация генератора случайных чисел
    MathSrand(GetTickCount());

    Print("Советник запущен!");
    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
    PrintFormat("Советник остановлен! Reason: %d", reason);
}

void OnTick() {

    if (PositionsTotal() == 0) {
        OpenRandomPosition();
    }

    else {
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
    if (basePosition.orderType == ORDER_TYPE_BUY) {
        ManageBuyPosition();
    } else {
        ManageSellPosition();
    }

    // Логика закрытия повисших убыточных позиций
    PositionsState state;
    GetPositionsState(state);

    if (state.buyCount > InpThresholdOneDirectionCount && state.sellCount > InpThresholdOneDirectionCount &&
        MathAbs(state.buyCount - state.sellCount) == 0) {
        CloseAllPositions();
    }
}

void ManageBuyPosition() {
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double tp = (basePosition.openPrice + ask) / 2;
    tp = NormalizeDouble(tp, _Digits);

    // Цена ушла в убыток от основной позиции на размер TP
    if (MathAbs(basePosition.openPrice - bid) >= InpTP_Pips * _Point) {
        OpenRandomPosition();
    }
}

void ManageSellPosition() {
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double tp = (basePosition.openPrice + bid) / 2;
    tp = NormalizeDouble(tp, _Digits);

    // Цена ушла в убыток от основной позиции на размер TP
    if (MathAbs(basePosition.openPrice - ask) >= InpTP_Pips * _Point) {
        OpenRandomPosition();
    }
}

void BasePositionOpenBuy() {
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = (InpSL_Pips > 0) ? ask - InpSL_Pips * _Point : 0.0;
    double tp = (InpTP_Pips > 0) ? ask + InpTP_Pips * _Point : 0.0;
    sl = (sl > 0) ? NormalizeDouble(sl, _Digits) : 0.0;
    tp = (tp > 0) ? NormalizeDouble(tp, _Digits) : 0.0;

    if (trade.Buy(InpLot, _Symbol, ask, sl, tp, "BasePosition BUY")) {

        basePosition.ticket = trade.ResultOrder();
        basePosition.openPrice = ask;
        basePosition.stopLoss = sl;
        basePosition.orderType = ORDER_TYPE_BUY;

        PrintFormat("BasePosition=%s", basePosition.ToString());
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

        basePosition.ticket = trade.ResultOrder();
        basePosition.openPrice = bid;
        basePosition.stopLoss = sl;
        basePosition.orderType = ORDER_TYPE_SELL;

        PrintFormat("BasePosition=%s", basePosition.ToString());
    }

    else {
        PrintFormat("Ошибка открытия BasePosition SELL: %s", trade.ResultRetcodeDescription());
    }
}

/**
 * Получить текущее состояние позиций
 */
void GetPositionsState(PositionsState &state) {
    state.buyCount = 0;
    state.sellCount = 0;
    state.farthestBuyTicket = 0;
    state.farthestSellTicket = 0;

    double farthestBuyOpenPrice = 0;
    double farthestSellOpenPrice = 0;

    // Перебираем все открытые позиции
    for (int i = 0; i < PositionsTotal(); i++) {
        // Получаем тикет позиции и одновременно выбираем её для работы
        ulong ticket = PositionGetTicket(i);

        if (ticket > 0) {

            // Подсчёт количества позиций по направлению
            ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

            if (positionType == POSITION_TYPE_BUY) {
                state.buyCount++;
            } else if (positionType == POSITION_TYPE_SELL) {
                state.sellCount++;
            }

            // Подсчёт самой дальней от текущей цены позиции Buy/Sell
            double priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);

            if (positionType == POSITION_TYPE_BUY && (farthestBuyOpenPrice == 0 || farthestBuyOpenPrice < priceOpen)) {
                farthestBuyOpenPrice = priceOpen;
                state.farthestBuyTicket = ticket;
            } else if (
                positionType == POSITION_TYPE_SELL && (farthestSellOpenPrice == 0 || farthestSellOpenPrice > priceOpen)
            ) {
                farthestSellOpenPrice = priceOpen;
                state.farthestSellTicket = ticket;
            }
        }
    }
}

/**
 * Закрыть все позиции
 */
void CloseAllPositions() {
    int n = PositionsTotal();

    ulong tickets[];
    ArrayResize(tickets, n);

    for (int i = 0; i < n; i++) {
        ulong ticket = PositionGetTicket(i);
        tickets[i] = ticket;
    }

    for (int i = 0; i < n; i++) {
        trade.PositionClose(tickets[i]);
    }

    ArrayFree(tickets);
}