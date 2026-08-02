//###<Experts/My/RandomBot/RandomBot.mq5>

/** Позиция */
struct Position {
    ulong ticket;            // Номер тикета
    double openPrice;        // Цена открытия
    double stopLoss;         // SL
    ENUM_POSITION_TYPE type; // Тип

    string ToString() const {
        return StringFormat(
            "Position(ticket=%d, openPrice=%G, stopLoss=%G, type=%s)",
            ticket,
            openPrice,
            stopLoss,
            EnumToString(type)
        );
    }
};

/** Состояние позиций */
struct PositionsState {
    int buyCount;             // Количество Buy позиций
    int sellCount;            // Количество Sell позиций
    ulong farthestBuyTicket;  // Самая дальняя от текущей цены Buy позиция
    ulong farthestSellTicket; // Самая дальняя от текущей цены Sell позиция
    double buyProfit;         // Общая прибыль по всем Buy позициям
    double sellProfit;        // Общая прибыль по всем Sell позициям

    void Init() {
        buyCount = 0;
        sellCount = 0;
        farthestBuyTicket = 0;
        farthestSellTicket = 0;
        buyProfit = 0.0;
        sellProfit = 0.0;
    }

    double GetBuyPercent() const {
        if (buyCount + sellCount == 0) {
            return 0.0;
        }

        return (double)buyCount / (buyCount + sellCount) * 100.0;
    }

    double GetSellPercent() const {
        if (buyCount + sellCount == 0) {
            return 0.0;
        }

        return (double)sellCount / (buyCount + sellCount) * 100.0;
    }

    double GetTotalProfit() const {
        return buyProfit + sellProfit;
    }
};

enum Switch {
    SWITCH_ON, // ✔️ On
    SWITCH_OFF // ❌ Off
};

enum RandomMode {
    RANDOM_MODE_FIFTY_FIFTY,        // 50 на 50
    RANDOM_MODE_FULL_BALANCE,       // 100% баланс
    RANDOM_MODE_FULL_DISBALANCE,    // 100% дисбаланс (сетка)
    RANDOM_MODE_WEIGHTED_BALANCE,   // Взвешенный баланс
    RANDOM_MODE_WEIGHTED_DISBALANCE // Взвешенный дисбаланс
};