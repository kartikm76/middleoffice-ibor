package com.kmakker.ibor.dto.analytics;

import java.util.List;

public record BrinsonAttributionDailyResponse(
        String portfolioCode,
        String benchmarkCode,
        List<DailyRow> dailyAttribution
) {
    public record DailyRow(
            String asOfDate,
            String segment,
            Double allocation,
            Double selection,
            Double interaction,
            Double total
    ) {}
}