package com.kmakker.ibor.dto.analytics;
import java.util.List;

public record PortfolioReturnResponse(
        String portfolioCode,
        List<DailyReturn> dailyReturns,
        Double periodReturn
) {
    public record DailyReturn(String asOfDate, Double twrr, Double totalMVBase) {}
}