package com.kmakker.ibor.dto;

import jakarta.validation.constraints.NotBlank;
import java.util.List;

public record HybridAskRequest(
        @NotBlank String question,
        @NotBlank String instrumentTicker,
        List<String> portfolioCodes,
        Integer topK
) {}
