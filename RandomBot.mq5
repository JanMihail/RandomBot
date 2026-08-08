#property copyright "RandomBot"
#property version "5.0"

#include "Functions.mqh"
#include "Structures.mqh"
#include "UI.mqh"
#include <Trade/Trade.mqh>

//================== INPUTS ==========================================
input group "⚙️ Настройки торговли";
input int INP_SL_PIPS = 0;   // Stop Loss в пипсах (0 = выключен)
input int INP_TP_PIPS = 200; // Take Profit в пипсах (0 = выключен)

input group "💰 Мани-менеджмент";
input double INP_LOT = 0.08;               // Базовый торговый лот
input double INP_LOT_PER_BALANCE = 1000.0; // Баланс на базовый лот (0 = фиксированный лот INP_LOT)
// input int INP_GRID_LOT_STEP = 5;           // Увеличивать лот каждые N позиций (0 = выключено)
// input double INP_GRID_LOT_ADD = 0.1;       // Прибавка к лоту за каждый шаг N позиций

input group "🔴 Контроль рисков (Защита)";
input double INP_MAX_DRAWDOWN_PERCENT = 50.0; // Макс. допустимая просадка в %
input int INP_THRESHOLD_ONE_DIRECTION = 5;    // Порог позиций одного направления для закрытия по балансу

input group "🎯 Контроль прибыли и цели";
input double INP_EQUITY_PROFIT_TARGET_PERCENT = 2.0; // Фиксация прибыли при приросте Equity в % (0 = выкл.)
input double INP_TARGET_DEPOSIT_PROFIT_KOEF = 3.0;   // Целевой множитель баланса до полной остановки (Иксы)

input group "🎲 Алгоритм выбора направления";
input RandomMode RANDOM_MODE = RANDOM_MODE_FULL_BALANCE; // Алгоритм случайного выбора направления
input double INP_MIN_PROBABILITY = 0.0;                  // Минимальный порог вероятности (для взвешенных режимов)
input double INP_MAX_PROBABILITY = 1.0;                  // Максимальный порог вероятности (для взвешенных режимов)

input group "📈 Графическая панель";
sinput Switch INP_UI_PANEL_ENABLED = SWITCH_ON; // Отображение информационной UI панели

input group "🔧 Служебные настройки";
input int INP_OPTIMIZATOR = 1; // Генератор прогонов (не влияет на логику)

//================== GLOBAL VARS======================================
Position basePosition;         // Основная позиция. От неё строится Random
PositionsState positionsState; // Текущее состояние позиций
CTrade trade;                  // Объект для выполнения торговых операций

double startAccountBalance; // Начальный баланс счёта при старте советника (не меняется)
double accountBalance;      // Баланс счёта после фиксации прибыли/убытка

int OnInit() {
    // Устанавливаем допустимое отклонение для торговли
    trade.SetDeviationInPoints(20);

    // инициализация начального состояния позиций
    positionsState.Init();

    // Инициализация генератора случайных чисел
    MathSrand(GetTickCount());

    // Инициализация панели с состоянием счёта и позиций
    CreatePositionsStatePanel();

    startAccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    accountBalance = startAccountBalance;

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

    // Применить управление рисками
    ApplyRiskManagement();

    // Применить управление прибылью
    ApplyProfitManagement();
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
    if (MathAbs(basePosition.openPrice - currentPriceForClosePosition) >= INP_TP_PIPS * _Point) {
        OpenBaseRandomPosition();
    }
}

void ApplyRiskManagement() {
    ApplyThresholdOneDirectionRiskManagement();
    ApplyMaxDrawdownRiskManagement();
}

void ApplyProfitManagement() {
    ApplyEquityTargetPercentProfitManagement();
    ApplyTargetDepositProfitManagement();
}

/** Логика закрытия повисших убыточных позиций в одном направлении при превышении порога */
void ApplyThresholdOneDirectionRiskManagement() {
    if (positionsState.buyCount >= INP_THRESHOLD_ONE_DIRECTION &&
        positionsState.sellCount >= INP_THRESHOLD_ONE_DIRECTION &&
        MathAbs(positionsState.buyCount - positionsState.sellCount) == 0) {
        CloseAllPositions();
        accountBalance = AccountInfoDouble(ACCOUNT_EQUITY);
    }
}

/** Логика фиксации убытка при достижении макс. допустимой просадки */
void ApplyMaxDrawdownRiskManagement() {
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);

    if (accountBalance == 0.0) {
        return;
    }

    double lossPercent = -(equity - accountBalance) / accountBalance * 100.0;

    if (lossPercent >= INP_MAX_DRAWDOWN_PERCENT) {
        CloseAllPositions();
        accountBalance = equity;
    }
}

/** Логика фиксации прибыли при приросте Equity в % */
void ApplyEquityTargetPercentProfitManagement() {
    if (INP_EQUITY_PROFIT_TARGET_PERCENT == 0.0) {
        return;
    }

    double equity = AccountInfoDouble(ACCOUNT_EQUITY);

    if (accountBalance == 0.0) {
        return;
    }

    double profitPercent = (equity - accountBalance) / accountBalance * 100.0;

    if (profitPercent >= INP_EQUITY_PROFIT_TARGET_PERCENT) {
        CloseAllPositions();
        accountBalance = equity;
    }
}

/** Логика фиксации прибыли при достижении финальных иксов и отключение советника */
void ApplyTargetDepositProfitManagement() {
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);

    if (equity / startAccountBalance >= INP_TARGET_DEPOSIT_PROFIT_KOEF) {
        CloseAllPositions();
        ExpertRemove();
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
    double sl = (INP_SL_PIPS > 0) ? ask - INP_SL_PIPS * _Point : 0.0;
    double tp = (INP_TP_PIPS > 0) ? ask + INP_TP_PIPS * _Point : 0.0;
    sl = (sl > 0) ? NormalizeDouble(sl, _Digits) : 0.0;
    tp = (tp > 0) ? NormalizeDouble(tp, _Digits) : 0.0;

    if (trade.Buy(INP_LOT, _Symbol, ask, sl, tp, "BasePosition BUY")) {

        basePosition.ticket = trade.ResultOrder();
        basePosition.openPrice = ask;
        basePosition.stopLoss = sl;
        basePosition.type = POSITION_TYPE_BUY;

        PrintFormat("BasePosition=%s", basePosition.ToString());

        UpdatePositionsState();
    }

    else {
        PrintFormat("Ошибка открытия BasePosition BUY: %s", trade.ResultRetcodeDescription());

        // Если код ошибки not enougn money, выключаем советник
        if (trade.ResultRetcode() == 10019) {
            CloseAllPositions();
            ExpertRemove();
        }
    }
}

void OpenBasePositionSell() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = (INP_SL_PIPS > 0) ? bid + INP_SL_PIPS * _Point : 0.0;
    double tp = (INP_TP_PIPS > 0) ? bid - INP_TP_PIPS * _Point : 0.0;
    sl = (sl > 0) ? NormalizeDouble(sl, _Digits) : 0.0;
    tp = (tp > 0) ? NormalizeDouble(tp, _Digits) : 0.0;

    if (trade.Sell(INP_LOT, _Symbol, bid, sl, tp, "BasePosition SELL")) {

        basePosition.ticket = trade.ResultOrder();
        basePosition.openPrice = bid;
        basePosition.stopLoss = sl;
        basePosition.type = POSITION_TYPE_SELL;

        PrintFormat("BasePosition=%s", basePosition.ToString());

        UpdatePositionsState();
    }

    else {
        PrintFormat("Ошибка открытия BasePosition SELL: %s", trade.ResultRetcodeDescription());

        // Если код ошибки not enougn money, выключаем советник
        if (trade.ResultRetcode() == 10019) {
            CloseAllPositions();
            ExpertRemove();
        }
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