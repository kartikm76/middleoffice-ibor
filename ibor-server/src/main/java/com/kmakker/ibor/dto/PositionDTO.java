package com.kmakker.ibor.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.math.BigDecimal;
import java.time.LocalDate;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record PositionDTO (
    @JsonProperty("asOf") LocalDate asOf,
    @JsonProperty("portfolioId") String portfolioId,
    @JsonProperty("instrumentId") String instrumentId,
    @JsonProperty("instrumentType") String instrumentType,
    @JsonProperty("netQty") BigDecimal netQty,
    @JsonProperty("price") BigDecimal price,
    @JsonProperty("priceSource") String priceSource,
    @JsonProperty("mktValue") BigDecimal mktValue,
    @JsonProperty("cost") BigDecimal cost,
    @JsonProperty("unrealizedPnl") BigDecimal unrealizedPnl,
    @JsonProperty("currency") String currency,
    @JsonProperty("contractMultiplier") BigDecimal contractMultiplier
) {}
