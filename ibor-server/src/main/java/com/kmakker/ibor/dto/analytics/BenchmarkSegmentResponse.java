package com.kmakker.ibor.dto.analytics;

import java.util.List;

public record BenchmarkSegmentResponse(
        String benchmarkCode,
        List<SegmentRow> segments
) {
    public record SegmentRow(String asOfDate, String segment, Double weight, Double returnPct) {}
}