package com.kmakker.ibor.dto;

import java.math.BigDecimal;
import java.time.Instant;

public record PriceRowDTO(
        Instant priceTs,
        BigDecimal price,
        String currency,
        String source
) {}

