package com.kmakker.ibor.dto;

import java.util.List;
public record SecurityReturnResponse(
        String portfolioCode,
        String asOfDate,
        List<SecurityRow> securities
) {
    public record SecurityRow(String ticker, String segment, Double weight, Double returnPct) {}
}