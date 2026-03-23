package com.kmakker.ibor.dto;

import java.time.OffsetDateTime;
import java.util.UUID;

public record ContextDTO(
        UUID docId,
        String title,
        String sourceUri,
        String author,
        OffsetDateTime updatedAt,
        int chunkIdx,
        String content
) {}
