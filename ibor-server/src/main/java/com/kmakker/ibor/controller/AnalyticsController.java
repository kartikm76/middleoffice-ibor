package com.kmakker.ibor.controller;

import com.kmakker.ibor.dto.*;
import com.kmakker.ibor.dto.analytics.BenchmarkSegmentResponse;
import com.kmakker.ibor.dto.analytics.BrinsonAttributionDailyResponse;
import com.kmakker.ibor.dto.analytics.BrinsonAttributionPeriodResponse;
import com.kmakker.ibor.dto.analytics.PortfolioReturnResponse;
import com.kmakker.ibor.service.AnalyticsService;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.*;

@Tag(name = "Analytics")
@RestController
@RequestMapping("/api/analytics")
public class AnalyticsController {

    private final AnalyticsService svc;

    public AnalyticsController(AnalyticsService svc) {
        this.svc = svc;
    }

    // ---------- Portfolio Returns ----------
    @GetMapping("/returns/portfolio")
    public PortfolioReturnResponse getPortfolioReturns(
            @RequestParam String portfolioCode,
            @RequestParam String startDate,
            @RequestParam String endDate
    ) {
        return svc.getPortfolioReturns(portfolioCode, startDate, endDate);
    }

    // ---------- Security Returns ----------
    @GetMapping("/returns/securities")
    public SecurityReturnResponse getSecurityReturns(
            @RequestParam String portfolioCode,
            @RequestParam String asOfDate
    ) {
        return svc.getSecurityReturns(portfolioCode, asOfDate);
    }

    // ---------- Benchmark Segments ----------
    @GetMapping("/benchmark/segments")
    public BenchmarkSegmentResponse getBenchmarkSegments(
            @RequestParam String benchmarkCode,
            @RequestParam String startDate,
            @RequestParam String endDate
    ) {
        return svc.getBenchmarkSegments(benchmarkCode, startDate, endDate);
    }

    // ---------- Daily Brinson Attribution ----------
    @GetMapping("/attribution/brinson/daily")
    public BrinsonAttributionDailyResponse getDailyBrinsonAttribution(
            @RequestParam String portfolioCode,
            @RequestParam String benchmarkCode,
            @RequestParam String startDate,
            @RequestParam String endDate
    ) {
        return svc.getDailyBrinsonAttribution(portfolioCode, benchmarkCode, startDate, endDate);
    }

    // ---------- Period Brinson Attribution ----------
    @GetMapping("/attribution/brinson/period")
    public BrinsonAttributionPeriodResponse getPeriodBrinsonAttribution(
            @RequestParam String portfolioCode,
            @RequestParam String benchmarkCode,
            @RequestParam String startDate,
            @RequestParam String endDate
    ) {
        return svc.getPeriodBrinsonAttribution(portfolioCode, benchmarkCode, startDate, endDate);
    }
}