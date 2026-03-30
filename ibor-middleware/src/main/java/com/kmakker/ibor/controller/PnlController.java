package com.kmakker.ibor.controller;

import com.kmakker.ibor.dto.analytics.PortfolioReturnResponse;
import com.kmakker.ibor.service.AnalyticsService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.Map;

@Tag(name = "PnL")
@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class PnlController {

    private final AnalyticsService analyticsService;

    /**
     * Simple P&L endpoint that returns delta for a portfolio as-of a date.
     * Compares market value at asOf date with previous business day.
     */
    @GetMapping("/pnl")
    public Map<String, Object> getPnlDelta(
            @RequestParam String portfolioCode,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate asOf
    ) {
        // Get prior day (assume 1-day lag for prior business day)
        LocalDate priorDate = asOf.minusDays(1);

        // Fetch returns for 1-day period
        PortfolioReturnResponse response = analyticsService.getPortfolioReturns(
                portfolioCode,
                priorDate.toString(),
                asOf.toString()
        );

        Map<String, Object> result = new HashMap<>();
        result.put("portfolioCode", portfolioCode);
        result.put("asOf", asOf.toString());
        result.put("priorDate", priorDate.toString());

        if (response != null && response.dailyReturns() != null && !response.dailyReturns().isEmpty()) {
            // Get current and prior day values from daily returns
            double currentMV = 0;
            double previousMV = 0;

            for (var daily : response.dailyReturns()) {
                if (daily.asOfDate().equals(asOf.toString())) {
                    currentMV = daily.totalMVBase() != null ? daily.totalMVBase() : 0;
                } else if (daily.asOfDate().equals(priorDate.toString())) {
                    previousMV = daily.totalMVBase() != null ? daily.totalMVBase() : 0;
                }
            }

            result.put("currentMarketValue", currentMV);
            result.put("previousMarketValue", previousMV);
            result.put("delta", currentMV - previousMV);
        } else {
            result.put("currentMarketValue", 0);
            result.put("previousMarketValue", 0);
            result.put("delta", 0);
        }

        return result;
    }
}
