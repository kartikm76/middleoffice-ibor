package com.kmakker.ibor.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

public record PositionSummaryDTO (
    LocalDate asOf,
    String portfolioCode,
    String instrumentCode,
    String instrumentType,
    BigDecimal netQty,
    BigDecimal price,
    String priceSource,
    BigDecimal mktValue,
    String currency
) {}
