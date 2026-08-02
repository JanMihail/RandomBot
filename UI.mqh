//###<Experts/My/RandomBot/RandomBot.mq5>

#include "Structures.mqh"

string uiObjPrefix = "PositionsStatePanel_";

/** Удаление панели с состоянием счёта и позиций */
void DeletePositionsStatePanel() {
    if (InpUiPanelEnabled == SWITCH_OFF) {
        return;
    }

    ObjectsDeleteAll(0, uiObjPrefix);
}

/** Создание панели с состоянием счёта и позиций */
void CreatePositionsStatePanel() {
    if (InpUiPanelEnabled == SWITCH_OFF) {
        return;
    }

    DeletePositionsStatePanel();

    // Размеры и координаты таблицы
    int startX = 20;                     // Отступ слева
    int startY = 20;                     // Отступ сверху
    int rowHeight = 30;                  // Высота строки
    int colWidths[] = {80, 65, 120, 70}; // Ширина колонок: [Пустая/Тип, Count, $, %]

    int rows = 6;
    int cols = 4;

    int borderWidth = 1;
    color borderColor = 0x999999;

    // 1. Создание объектов ячеек и сетки
    int currentY = startY;
    for (int r = 0; r < rows; r++) {
        int currentX = startX;

        for (int c = 0; c < cols; c++) {
            if (r == 0 && c == 0) {
                currentX += colWidths[c];
                continue;
            }

            string bgName = uiObjPrefix + "BG_" + IntegerToString(r) + "_" + IntegerToString(c);

            if (ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0)) {
                ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, currentX);
                ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, currentY);
                ObjectSetInteger(0, bgName, OBJPROP_XSIZE, colWidths[c] + borderWidth);
                ObjectSetInteger(0, bgName, OBJPROP_YSIZE, rowHeight + borderWidth);

                // Настройка границ и фона
                ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, clrWhite);
                ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
                ObjectSetInteger(0, bgName, OBJPROP_WIDTH, borderWidth);
                ObjectSetInteger(0, bgName, OBJPROP_COLOR, borderColor);
                ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
            }

            currentX += colWidths[c];
        }
        currentY += rowHeight;
    }

    // 2. Создание объектов с текстом
    string textObjectNames[6][4] = {
        {"", "HEADER_COUNT", "HEADER_MONEY", "HEADER_PERCENT"},
        {"BUY", "BUY_COUNT", "BUY_PROFIT", "BUY_PERCENT"},
        {"SELL", "SELL_COUNT", "SELL_PROFIT", "SELL_PERCENT"},
        {"TOTAL", "TOTAL_COUNT", "TOTAL_PROFIT", ""},
        {"BALANCE", "", "BALANCE_SUM", ""},
        {"EQUITY", "", "EQUITY_SUM", "EQUITY_PERCENT"}
    };

    string textValues[6][4] = {
        {"", "Count", "$", "%"},
        {"Buy", "0", "0.00", "0.00"},
        {"Sell", "0", "0.00", "0.00"},
        {"Total", "0", "0.00", ""},
        {"Balance", "", "0.00", ""},
        {"Equity", "", "0.00", "0.00"}
    };

    int fontSize = 10;

    currentY = startY;
    for (int r = 0; r < rows; r++) {
        int currentX = startX;
        for (int c = 0; c < cols; c++) {
            string text = textValues[r][c];

            if (StringLen(text) == 0) {
                currentX += colWidths[c];
                continue;
            }

            string labelName = uiObjPrefix + "TEXT_" + textObjectNames[r][c];

            if (ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0)) {
                bool isHeader = (r == 0);
                bool isFirstCol = (c == 0);

                string fontName = (isHeader || isFirstCol) ? "Consolas Bold" : "Consolas";

                ObjectSetString(0, labelName, OBJPROP_FONT, fontName);
                ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, fontSize);
                ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrBlack);
                ObjectSetString(0, labelName, OBJPROP_TEXT, text);
                ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);

                int textY = currentY + (rowHeight / 2); // Центрирование по вертикали

                if (isFirstCol) {
                    // Выравнивание ПО ЛЕВОМУ краю (с небольшим отступом в 10px)
                    ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
                    ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, currentX + 5);
                    ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, textY);
                } else {
                    // Выравнивание ПО ПРАВОМУ краю (с отступом 10px от правой границы ячейки)
                    ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_RIGHT);
                    ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, currentX + colWidths[c] - 5);
                    ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, textY);
                }
            }

            currentX += colWidths[c];
        }
        currentY += rowHeight;
    }

    ChartRedraw();
}

/** Обновление панели с состоянием счёта и позиций */
void UpdatePositionsStatePanel(const PositionsState &state) {
    if (InpUiPanelEnabled == SWITCH_OFF) {
        return;
    }

    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);

    string labelName = uiObjPrefix + "TEXT_" + "BUY_COUNT";
    ObjectSetString(0, labelName, OBJPROP_TEXT, IntegerToString(state.buyCount));

    labelName = uiObjPrefix + "TEXT_" + "SELL_COUNT";
    ObjectSetString(0, labelName, OBJPROP_TEXT, IntegerToString(state.sellCount));

    labelName = uiObjPrefix + "TEXT_" + "TOTAL_COUNT";
    ObjectSetString(0, labelName, OBJPROP_TEXT, IntegerToString(state.buyCount + state.sellCount));

    labelName = uiObjPrefix + "TEXT_" + "BUY_PROFIT";
    ObjectSetString(0, labelName, OBJPROP_TEXT, StringFormat("%.2f", state.buyProfit));
    ObjectSetInteger(0, labelName, OBJPROP_COLOR, state.buyProfit >= 0 ? clrGreen : clrRed);

    labelName = uiObjPrefix + "TEXT_" + "SELL_PROFIT";
    ObjectSetString(0, labelName, OBJPROP_TEXT, StringFormat("%.2f", state.sellProfit));
    ObjectSetInteger(0, labelName, OBJPROP_COLOR, state.sellProfit >= 0 ? clrGreen : clrRed);

    labelName = uiObjPrefix + "TEXT_" + "TOTAL_PROFIT";
    ObjectSetString(0, labelName, OBJPROP_TEXT, StringFormat("%.2f", state.GetTotalProfit()));
    ObjectSetInteger(0, labelName, OBJPROP_COLOR, state.GetTotalProfit() >= 0 ? clrGreen : clrRed);

    labelName = uiObjPrefix + "TEXT_" + "BUY_PERCENT";
    ObjectSetString(0, labelName, OBJPROP_TEXT, StringFormat("%.2f", state.GetBuyPercent()));

    labelName = uiObjPrefix + "TEXT_" + "SELL_PERCENT";
    ObjectSetString(0, labelName, OBJPROP_TEXT, StringFormat("%.2f", state.GetSellPercent()));

    labelName = uiObjPrefix + "TEXT_" + "BALANCE_SUM";
    ObjectSetString(0, labelName, OBJPROP_TEXT, StringFormat("%.2f", balance));

    labelName = uiObjPrefix + "TEXT_" + "EQUITY_SUM";
    ObjectSetString(0, labelName, OBJPROP_TEXT, StringFormat("%.2f", equity));

    labelName = uiObjPrefix + "TEXT_" + "EQUITY_PERCENT";
    ObjectSetString(0, labelName, OBJPROP_TEXT, StringFormat("%.2f", -(balance - equity) / balance * 100.0));
}