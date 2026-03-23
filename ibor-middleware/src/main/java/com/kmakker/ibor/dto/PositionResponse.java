package com.kmakker.ibor.dto;

import java.time.OffsetDateTime;
import java.util.List;

public record PositionResponse(
        PositionAggregateDTO aggregate,
        List<ByPortfolioDTO> byPortfolio,
        OffsetDateTime asOf
) {}
