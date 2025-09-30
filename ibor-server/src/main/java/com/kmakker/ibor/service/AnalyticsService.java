package com.kmakker.ibor.service;

import com.kmakker.ibor.dto.*;
import com.kmakker.ibor.dto.analytics.BenchmarkSegmentResponse;
import com.kmakker.ibor.dto.analytics.BrinsonAttributionDailyResponse;
import com.kmakker.ibor.dto.analytics.BrinsonAttributionPeriodResponse;
import com.kmakker.ibor.dto.analytics.PortfolioReturnResponse;
import com.kmakker.ibor.repositories.analytics.BenchmarkSegmentRepository;
import com.kmakker.ibor.repositories.analytics.BrinsonAttributionRepository;
import com.kmakker.ibor.repositories.analytics.PortfolioReturnRepository;
import com.kmakker.ibor.repositories.analytics.SecurityReturnRepository;
import org.springframework.stereotype.Service;

@Service
public class AnalyticsService {

    private final PortfolioReturnRepository portfolioRepo;
    private final SecurityReturnRepository securityRepo;
    private final BenchmarkSegmentRepository benchmarkRepo;
    private final BrinsonAttributionRepository brinsonRepo;

    public AnalyticsService(PortfolioReturnRepository portfolioRepo,
                            SecurityReturnRepository securityRepo,
                            BenchmarkSegmentRepository benchmarkRepo,
                            BrinsonAttributionRepository brinsonRepo) {
        this.portfolioRepo = portfolioRepo;
        this.securityRepo = securityRepo;
        this.benchmarkRepo = benchmarkRepo;
        this.brinsonRepo = brinsonRepo;
    }

    public PortfolioReturnResponse getPortfolioReturns(String portfolioCode, String startDate, String endDate) {
        var rows = portfolioRepo.findDailyReturns(portfolioCode, startDate, endDate);
        double product = rows.stream().mapToDouble(r -> 1 + r.twrr()).reduce(1, (a, b) -> a * b);
        double period = product - 1;
        return new PortfolioReturnResponse(portfolioCode, rows, period);
    }

    public SecurityReturnResponse getSecurityReturns(String portfolioCode, String asOfDate) {
        var rows = securityRepo.findbyPortfolioAndDate(portfolioCode, asOfDate);
        return new SecurityReturnResponse(portfolioCode, asOfDate, rows);
    }

    public BenchmarkSegmentResponse getBenchmarkSegments(String benchmarkCode, String startDate, String endDate) {
        var rows = benchmarkRepo.findSegments(benchmarkCode, startDate, endDate);
        return new BenchmarkSegmentResponse(benchmarkCode, rows);
    }

    public BrinsonAttributionDailyResponse getDailyBrinsonAttribution(String portfolioCode, String benchmarkCode, String startDate, String endDate) {
        var rows = brinsonRepo.findDaily(portfolioCode, benchmarkCode, startDate, endDate);
        return new BrinsonAttributionDailyResponse(portfolioCode, benchmarkCode, rows);
    }

    public BrinsonAttributionPeriodResponse getPeriodBrinsonAttribution(String portfolioCode, String benchmarkCode, String startDate, String endDate) {
        var rows = brinsonRepo.findPeriod(portfolioCode, benchmarkCode, startDate, endDate);
        double total = rows.stream().mapToDouble(r -> r.total()).sum();
        return new BrinsonAttributionPeriodResponse(portfolioCode, benchmarkCode, rows, total);
    }
}