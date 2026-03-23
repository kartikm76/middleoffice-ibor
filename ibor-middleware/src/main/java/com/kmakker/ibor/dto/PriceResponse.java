package com.kmakker.ibor.dto;

import java.util.List;

public record PriceResponse(
        String instrumentCode,
        String portfolioCode,
        String baseCurrency,
        List<PriceRowDTO> rows
) {}
