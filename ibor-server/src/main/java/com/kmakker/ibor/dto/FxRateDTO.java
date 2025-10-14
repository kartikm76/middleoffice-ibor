package com.kmakker.ibor.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

public record FxRateDTO(
        LocalDate fxDate,
        String fromCurrency,
        String toCurrency,
        BigDecimal rate
) {}
