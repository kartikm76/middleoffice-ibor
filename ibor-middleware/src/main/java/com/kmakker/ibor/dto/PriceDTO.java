package com.kmakker.ibor.dto;

// it may have to be removed
import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record PriceDTO(
        BigDecimal priceLast,
        String currency,
        OffsetDateTime priceTime
) {}
