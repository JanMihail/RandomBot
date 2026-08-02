#property copyright "RandomBot"
#property version "5.0"

#include "Functions.mqh"
#include "Structures.mqh"
#include "UI.mqh"
#include <Trade/Trade.mqh>

//================== INPUTS ==========================================
input int InpOptimizator = 1; // Параметр для генерации прогонов (не влияет ни на что)

input group "=== ТОРГОВЛЯ ===";
input double InpLot = 0.08; // Лот
input int InpSL_Pips = 0;   // Stop Loss, пипсов (0 = без SL)
input int InpTP_Pips = 200; // Take Profit, пипсов (0 = без TP)

input group "=== РЕЖИМ РАНДОМА ===";
input RandomMode RANDOM_MODE = RANDOM_MODE_FULL_BALANCE; // Режим случайности направления открытия позиций

input group "=== РЕЖИМ ЗАКРЫТИЯ ПОЗИЦИЙ ===";
input int InpThresholdOneDirectionCount = 5; // Если >= Buy&Sell, закрываем всё при достижении баланса

input group "=== ВНЕШНИЙ ВИД ===";
sinput Switch InpUiPanelEnabled = SWITCH_ON; // Вкл/Выкл UI панель

//================== GLOBAL VARS======================================
Position basePosition;         // Основная позиция. От неё строится Random
PositionsState positionsState; // Текущее состояние позиций
CTrade trade;                  // Объект для выполнения торговых операций

int OnInit() {
    // Устанавливаем допустимое отклонение для торговли
    trade.SetDeviationInPoints(20);

    // инициализация начального состояния позиций
    positionsState.Init();

    // Инициализация генератора случайных чисел
    MathSrand(GetTickCount());

    // Инициализация панели с состоянием счёта и позиций
    CreatePositionsStatePanel();

    Print("Советник запущен!");
    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
    // Удаление панели с состоянием счёта и позиций
    DeletePositionsStatePanel();

    PrintFormat("Советник остановлен! Reason: %d", reason);
}

void OnTick() {
    // Обновление состояния позиций
    UpdatePositionsState();

    // Проверка и открытие базовой позиции если нужно
    CheckAndOpenNewBasePositionIfNeed();

    // Управление закрытием позиций
    ManageClosePositions();
}

void CheckAndOpenNewBasePositionIfNeed() {

    if (PositionsTotal() == 0) {
        OpenBaseRandomPosition();
        return;
    }

    double currentPriceForClosePosition = basePosition.type == POSITION_TYPE_BUY
                                              ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                              : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    // Цена ушла в +/- от основной позиции на размер TP
    if (MathAbs(basePosition.openPrice - currentPriceForClosePosition) >= InpTP_Pips * _Point) {
        OpenBaseRandomPosition();
    }
}

void ManageClosePositions() {
    // Логика закрытия повисших убыточных позиций
    if (positionsState.buyCount >= InpThresholdOneDirectionCount &&
        positionsState.sellCount >= InpThresholdOneDirectionCount &&
        MathAbs(positionsState.buyCount - positionsState.sellCount) == 0) {
        CloseAllPositions();
    }
}

void OpenBaseRandomPosition() {
    if (GetRandomWeightedDirection(positionsState.buyCount, positionsState.sellCount) == POSITION_TYPE_BUY) {
        OpenBasePositionBuy();
    } else {
        OpenBasePositionSell();
    }
}

void OpenBasePositionBuy() {
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = (InpSL_Pips > 0) ? ask - InpSL_Pips * _Point : 0.0;
    double tp = (InpTP_Pips > 0) ? ask + InpTP_Pips * _Point : 0.0;
    sl = (sl > 0) ? NormalizeDouble(sl, _Digits) : 0.0;
    tp = (tp > 0) ? NormalizeDouble(tp, _Digits) : 0.0;

    if (trade.Buy(InpLot, _Symbol, ask, sl, tp, "BasePosition BUY")) {

        basePosition.ticket = trade.ResultOrder();
        basePosition.openPrice = ask;
        basePosition.stopLoss = sl;
        basePosition.type = POSITION_TYPE_BUY;

        PrintFormat("BasePosition=%s", basePosition.ToString());

        UpdatePositionsState();
    }

    else {
        PrintFormat("Ошибка открытия BasePosition BUY: %s", trade.ResultRetcodeDescription());
    }
}

void OpenBasePositionSell() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = (InpSL_Pips > 0) ? bid + InpSL_Pips * _Point : 0.0;
    double tp = (InpTP_Pips > 0) ? bid - InpTP_Pips * _Point : 0.0;
    sl = (sl > 0) ? NormalizeDouble(sl, _Digits) : 0.0;
    tp = (tp > 0) ? NormalizeDouble(tp, _Digits) : 0.0;

    if (trade.Sell(InpLot, _Symbol, bid, sl, tp, "BasePosition SELL")) {

        basePosition.ticket = trade.ResultOrder();
        basePosition.openPrice = bid;
        basePosition.stopLoss = sl;
        basePosition.type = POSITION_TYPE_SELL;

        PrintFormat("BasePosition=%s", basePosition.ToString());

        UpdatePositionsState();
    }

    else {
        PrintFormat("Ошибка открытия BasePosition SELL: %s", trade.ResultRetcodeDescription());
    }
}

/**
 * Обновить текущее состояние позиций
 */
void UpdatePositionsState() {
    positionsState.Init();

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
                positionsState.buyCount++;
            } else if (positionType == POSITION_TYPE_SELL) {
                positionsState.sellCount++;
            }

            // Подсчёт самой дальней от текущей цены позиции Buy/Sell
            double priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);

            if (positionType == POSITION_TYPE_BUY && (farthestBuyOpenPrice == 0 || farthestBuyOpenPrice < priceOpen)) {
                farthestBuyOpenPrice = priceOpen;
                positionsState.farthestBuyTicket = ticket;
            } else if (
                positionType == POSITION_TYPE_SELL && (farthestSellOpenPrice == 0 || farthestSellOpenPrice > priceOpen)
            ) {
                farthestSellOpenPrice = priceOpen;
                positionsState.farthestSellTicket = ticket;
            }

            // Подсчёт суммарной прибыли по Buy/Sell
            double totalProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

            if (positionType == POSITION_TYPE_BUY) {
                positionsState.buyProfit += totalProfit;
            } else if (positionType == POSITION_TYPE_SELL) {
                positionsState.sellProfit += totalProfit;
            }
        }
    }

    UpdatePositionsStatePanel(positionsState);
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