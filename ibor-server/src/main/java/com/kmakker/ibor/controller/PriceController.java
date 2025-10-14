package com.kmakker.ibor.controller;

import com.kmakker.ibor.dto.PriceRowDTO;
import com.kmakker.ibor.service.PriceService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@RestController
@RequestMapping(path = "/api/prices", produces = MediaType.APPLICATION_JSON_VALUE)
@Tag(name = "Prices", description = "Price-related endpoints")
public class PriceController {
    private final PriceService priceService;

    public PriceController(PriceService priceService) {
        this.priceService = priceService;
    }

    /**
     * Get raw prices for an instrument; optionally normalize to a baseCurrency.
     * Examples:
     *  GET /api/prices/EQ-IBM?from=2025-01-01&to=2025-01-10
     *  GET /api/prices/EQ-IBM?from=2025-01-01&to=2025-01-10&source=BBG
     *  GET /api/prices/EQ-IBM?from=2025-01-01&to=2025-01-10&baseCurrency=USD
     */

    @GetMapping("/{instrumentCode}")
    public List<PriceRowDTO> getPrices(
            @PathVariable String instrumentCode,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String source,
            @RequestParam(required = false) String baseCurrency
    ) {
        return priceService.getPrices(
                instrumentCode,
                from,
                to,
                source,
                baseCurrency);
    }
}
