package com.kmakker.ibor.dto.analytics;

import java.util.List;

public record BrinsonAttributionPeriodResponse(
        String portfolioCode,
        String benchmarkCode,
        List<SegmentRow> periodAttribution,
        Double totalAttribution
) {
    public record SegmentRow(
            String segment,
            Double allocation,
            Double selection,
            Double interaction,
            Double total
    ) {}
}