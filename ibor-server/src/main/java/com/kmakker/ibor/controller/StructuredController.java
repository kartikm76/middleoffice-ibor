package com.kmakker.ibor.controller;

import com.kmakker.ibor.dto.ByPortfolioDTO;
import com.kmakker.ibor.dto.CashProjectionResponse;
import com.kmakker.ibor.dto.CashRowDTO;
import com.kmakker.ibor.dto.PositionAggregateDTO;
import com.kmakker.ibor.dto.PositionResponse;
import com.kmakker.ibor.dto.PriceDTO;
import com.kmakker.ibor.service.StructuredService;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;

@Tag(name = "Structured")
@RestController
@RequestMapping("/api/structured")
public class StructuredController {

    private final StructuredService svc;

    public StructuredController(StructuredService svc) {
        this.svc = svc;
    }

    @GetMapping("/position")
    public PositionResponse position(
            @RequestParam("tickerOrId") String tickerOrId,
            @RequestParam(value = "portfolioIds", required = false) List<String> portfolioCodes
    ){
        Map<String,Object> facts = svc.getPositionAggregate(tickerOrId, portfolioCodes);
        List<Map<String,Object>> perPf = svc.byPortfolio(tickerOrId);

        PositionAggregateDTO agg = new PositionAggregateDTO(
                ((Number)facts.get("instrument_id")).intValue(),
                (String) facts.getOrDefault("ticker", tickerOrId),
                ((Number)facts.get("qty")).doubleValue(),
                (String) facts.get("side"),
                ((Number)facts.get("market_value")).doubleValue(),
                mapPriceDTO((Map<String,Object>) facts.get("price"))
        );

        List<ByPortfolioDTO> byPortfolio = perPf.stream()
                .map(row -> new ByPortfolioDTO(
                        ((Number)row.get("portfolio_id")).intValue(),
                        (BigDecimal) row.get("qty")
                ))
                .toList();

        return new PositionResponse(agg, byPortfolio, now());
    }

    @GetMapping("/cash-projection")
    public CashProjectionResponse cash(
            @RequestParam("portfolioIds") List<String> portfolioCodes,
            @RequestParam(value = "days", defaultValue = "7") int days
    ){
        List<Map<String,Object>> rows = svc.cashProjection(portfolioCodes, days);
        List<CashRowDTO> dto = rows.stream().map(r -> new CashRowDTO(
                ((Number)r.get("portfolio_id")).intValue(),
                (String) r.get("ccy"),
                (java.time.LocalDate) r.get("value_dt"),
                (BigDecimal) r.get("net"),
                (List<String>) r.getOrDefault("drivers", List.of())
        )).toList();
        return new CashProjectionResponse(dto, now());
    }

    private static PriceDTO mapPriceDTO(Map<String,Object> price){
        if (price == null) return new PriceDTO(null, null, null);
        return new PriceDTO(
                (BigDecimal) price.get("price_last"),
                (String) price.get("currency"),
                (java.time.OffsetDateTime) price.get("price_time")
        );
    }

    private static OffsetDateTime now(){ return OffsetDateTime.now(ZoneOffset.UTC); }
}