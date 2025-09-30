package com.kmakker.ibor.dto;

import java.time.OffsetDateTime;
import java.util.List;

public record HybridAnswerResponse(
        String answer,
        PositionAggregateDTO facts,
        List<ContextDTO> contexts,
        OffsetDateTime asOf
) {}
