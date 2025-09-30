package com.kmakker.ibor.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(name = "rag_chunks")
public class RagChunk {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "doc_id", nullable = false)
    private RagDocument document;

    @Column(name = "chunk_idx", nullable = false)
    private int chunkIdx;

    @Column(columnDefinition = "text", nullable = false)
    private String content;

    @Column(name = "content_hash", nullable = false)
    private String contentHash;

    /**
     * Java side: String in pgvector literal form "[f1,f2,...]".
     * DB side: vector(1536). ColumnTransformer casts bind parameter to vector on INSERT/UPDATE.
     */
    @org.hibernate.annotations.ColumnTransformer(write = "?::vector")
    @Column(name = "embedding", columnDefinition = "vector(1536)", nullable = false)
    private String embedding;
}