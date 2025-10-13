package com.kmakker.ibor.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record TransactionDTO (
        String source,           // TRADE / ADJUST / CORP_ACT
        String externalId,       // trade id / adjustment id / corp action id
        LocalDateTime transactionDate,
        String action,           // BUY / SELL / ADJUST / CORP_ACT
        BigDecimal quantity,      // quantity of the transaction
        BigDecimal price,         // price of the transaction
        BigDecimal grossAmount,   // gross amount of the transaction
        String broker,
        String strategy,
        String notes
) {}
