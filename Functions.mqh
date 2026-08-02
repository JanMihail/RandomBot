//###<Experts/My/RandomBot/RandomBot.mq5>

/** Генерация случайного направления сделки с учетом баланса позиций */
ENUM_POSITION_TYPE GetRandomWeightedDirection(int buyCount, int sellCount) {

    if (RANDOM_MODE == RANDOM_MODE_FIFTY_FIFTY) {
        return (MathRand() % 2 == 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
    }

    int total = buyCount + sellCount;

    if (total == 0) {
        return (MathRand() % 2 == 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
    }

    if (RANDOM_MODE == RANDOM_MODE_FULL_BALANCE) {
        return buyCount < sellCount ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
    }

    double buyProbability = 0.0;

    if (RANDOM_MODE == RANDOM_MODE_WEIGHTED_BALANCE) {
        buyProbability = (double)sellCount / total;
    }

    else if (RANDOM_MODE == RANDOM_MODE_FULL_DISBALANCE) {
        buyProbability = (double)buyCount / total;
    }

    else if (RANDOM_MODE == RANDOM_MODE_WEIGHTED_DISBALANCE) {
        buyProbability = (double)buyCount / total;
        buyProbability = MathMax(0.2, buyProbability);
        buyProbability = MathMin(0.8, buyProbability);
    }

    else {
        PrintFormat("Ошибка: неизвестное значение RANDOM_MODE");
    }

    // randValue находится строго в диапазоне [0.0, 1.0)
    // Максимальное значение: 32767 / 32768.0 = 0.9999694824...
    double randValue = (double)MathRand() / 32768.0;

    if (randValue < buyProbability) {
        return POSITION_TYPE_BUY;
    } else {
        return POSITION_TYPE_SELL;
    }
}