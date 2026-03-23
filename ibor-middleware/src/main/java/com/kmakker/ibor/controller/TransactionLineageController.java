package com.kmakker.ibor.controller;

import com.kmakker.ibor.dto.PositionDetailDTO;
import com.kmakker.ibor.service.TransactionLineageService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/positions")
public class TransactionLineageController {
    private final TransactionLineageService transactionLineageService;

    public TransactionLineageController(TransactionLineageService transactionLineageService) {
        this.transactionLineageService = transactionLineageService;
    }

    @GetMapping("/{portfolioCode}/{instrumentCode}")
    public ResponseEntity<PositionDetailDTO> getDetail(
            @PathVariable String portfolioCode,
            @PathVariable String instrumentCode,
            @RequestParam LocalDate asOf,
            @RequestParam(value = "lotView", required = false, defaultValue = "NONE") String lotView) {
        var detail = transactionLineageService.getDetail(asOf, portfolioCode, instrumentCode, lotView);
        return ResponseEntity.ok()
                .header("x-contract-Version", "1")
                .body(detail);
    }
}
