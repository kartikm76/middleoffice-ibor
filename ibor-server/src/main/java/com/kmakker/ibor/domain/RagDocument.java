package com.kmakker.ibor.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "rag_documents")
public class RagDocument {

    @Id
    @Column(name = "doc_id", nullable = false, updatable = false)
    private UUID docId;

    @Column(name = "source_uri", nullable = false)
    private String sourceUri;

    @Column(name = "source_type", nullable = false)
    private String sourceType;

    private String title;
    private String author;

    @Column(name = "created_at")
    private OffsetDateTime createdAt;

    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "meta", columnDefinition = "jsonb", nullable = false)
    private String meta;

    @JdbcTypeCode(SqlTypes.ARRAY)
    @Column(name = "instrument_int_ids", columnDefinition = "int[]", nullable = false)
    private Integer[] instrumentIntIds;

    @JdbcTypeCode(SqlTypes.ARRAY)
    @Column(name = "portfolio_int_ids", columnDefinition = "int[]", nullable = false)
    private Integer[] portfolioIntIds;
}