package com.kmakker.ibor.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record PriceDTO(
        BigDecimal priceLast,
        String currency,
        OffsetDateTime priceTime
) {}
