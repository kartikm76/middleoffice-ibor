package com.kmakker.ibor.dto;

import java.math.BigDecimal;

public record ByPortfolioDTO(
        int portfolioId,
        BigDecimal qty
) {}
