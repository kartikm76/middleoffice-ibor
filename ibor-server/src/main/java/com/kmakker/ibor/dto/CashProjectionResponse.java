package com.kmakker.ibor.dto;

import java.time.OffsetDateTime;
import java.util.List;

public record CashProjectionResponse(
        List<CashRowDTO> rows,
        OffsetDateTime asOf
) {}
