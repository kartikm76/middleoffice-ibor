package com.kmakker.ibor.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

public class LotDTO {
    String lotId;
    LocalDate openDate;
    BigDecimal openQuantity;
    BigDecimal avgPrice;
    BigDecimal cost;
    BigDecimal realizedPnl;
}
