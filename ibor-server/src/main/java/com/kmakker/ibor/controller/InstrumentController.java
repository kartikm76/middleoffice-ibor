package com.kmakker.ibor.controller;

import com.kmakker.ibor.model.instrument.Instrument;
import com.kmakker.ibor.service.InstrumentService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.NotBlank;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.OffsetDateTime;

@RestController
@RequestMapping("/api/instruments")
@Tag(name = "Instruments", description = "Instrument-related endpoints")

public class InstrumentController {
    private final InstrumentService instrumentService;

    public InstrumentController(InstrumentService instrumentService) {
        this.instrumentService = instrumentService;
    }

    @GetMapping("/{instrumentCode}")
    @Operation(summary = "Get instrument details")
    @ApiResponse(responseCode = "200", description = "Instrument found")
    @ApiResponse(responseCode = "404", description = "Instrument not found")
    public ResponseEntity<?> getInstrumentAsOf(
            @PathVariable @NotBlank String instrumentCode,
            @RequestParam("asOf") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate asOfDate
    ) {
        return instrumentService.getInstrumentAsOf(instrumentCode, asOfDate)
                .<ResponseEntity<?>>map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND).body(
                        new NotFoundResponse(
                                "Instrument not found for the given date",
                                instrumentCode,
                                asOfDate,
                                OffsetDateTime.now()
                        )
                ));
    }
    /** Simple JSON error payload for not-found responses. */
    public record NotFoundResponse(
            String message,
            String instrumentCode,
            LocalDate asOfDate,
            OffsetDateTime timestamp
    ) {}
}


