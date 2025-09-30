package com.kmakker.ibor.dto;

public record PositionAggregateDTO(
        int instrumentId,
        String ticker,
        double qty,
        String side,
        double marketValue,
        PriceDTO price
) {}
