package com.kmakker.ibor.dto;

import jakarta.validation.constraints.NotBlank;
import java.util.List;

public record IngestNoteRequest(
        @NotBlank String title,
        @NotBlank String author,
        @NotBlank String text,
        List<String> instrumentTickers,
        List<String> portfolioCodes
) {}
