package com.kmakker.ibor.controller;

import com.kmakker.ibor.dto.PositionDTO;
import com.kmakker.ibor.service.PositionService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api")
@Validated
public class PositionController {
    private static final String CONTRACT_VERSION = "1";
    private final PositionService positionService;

    public PositionController(PositionService positionService) {
        this.positionService = positionService;
    }

    @GetMapping("/positions")
    @Operation(summary = "List positions as-of a date for a portfolio")
    public ResponseEntity<List<PositionDTO>> getPositions(
            @Parameter(description = "As-of date (YYYY-MM-DD)", required = true)
            @RequestParam("asOf") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate asOf,
            @Parameter(description = "Portfolio Code (e.g. 'P-ALPHA')", required = true)
            @RequestParam("portfolioCode") String portfolioCode,
            @Parameter(description = "Page number (default 1)", required = false)
            @RequestParam(value = "page", required = false) Integer page,
            @Parameter(description = "Page size (default 100, max 500)", required = false)
            @RequestParam(value = "size", required = false) Integer size) {
        if (page == null || page < 1) {
            page = 1;
        }
        if (size == null || size <= 0) {
            size = 100;
        }
        List<PositionDTO> positions = positionService.getPositions(asOf, portfolioCode, page, size);
        return ResponseEntity
                .ok()
                .header("x-contract-version", CONTRACT_VERSION)
                .body(positions);
    }
}

