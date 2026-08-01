//###<Experts/My/RandomBot/RandomBot.mq5>

/** Позиция */
struct Position {
    ulong ticket;              // Номер тикета
    double openPrice;          // Цена открытия
    double stopLoss;           // SL
    ENUM_ORDER_TYPE orderType; // Тип

    string ToString() const {
        return StringFormat(
            "Position(ticket=%d, openPrice=%G, stopLoss=%G, orderType=%s)",
            ticket,
            openPrice,
            stopLoss,
            EnumToString(orderType)
        );
    }
};

/** Состояние позиций */
struct PositionsState {
    int buyCount;             // Количество Buy позиций
    int sellCount;            // Количество Sell позиций
    ulong farthestBuyTicket;  // Самая дальняя от текущей цены Buy позиция
    ulong farthestSellTicket; // Самая дальняя от текущей цены Sell позиция
};