package com.kmakker.ibor.controller;

import com.kmakker.ibor.dto.PositionSummaryDTO;
import com.kmakker.ibor.service.PositionCompositionService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/positions")

public class PositionCompositionController {
    private final PositionCompositionService positionCompositionService;

    public PositionCompositionController(PositionCompositionService positionCompositionService) {
        this.positionCompositionService = positionCompositionService;
    }

    @GetMapping("/composition")
    public ResponseEntity<List<PositionSummaryDTO>> getComposition(
            @RequestParam("asOf") LocalDate asOf,
            @RequestParam("portfolioCode") String portfolioCode,
            @RequestParam(value = "page", defaultValue = "1") Integer page,
            @RequestParam(value = "size", defaultValue = "50") Integer size) {
        var composition = positionCompositionService.getComposition(asOf, portfolioCode, page, size);
        return ResponseEntity.ok()
                .header("X-Total-Count", String.valueOf(composition.size()))
                .body(composition);
    }
}