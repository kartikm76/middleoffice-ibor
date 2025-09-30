package com.kmakker.ibor.repositories;

import com.kmakker.ibor.domain.RagChunk;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

public interface RagChunkRepository extends JpaRepository<RagChunk, Long> {

    @Modifying
    @Transactional
    @Query(value = """
        insert into rag_chunks (doc_id, chunk_idx, content, content_hash, embedding)
        values (:docId, :chunkIdx, :content, :hash, (:embeddingLiteral)::vector) 
    """, nativeQuery = true)
    int insertChunkWithVector(@Param("docId") UUID docId,
                               @Param("chunkIdx") int chunkIdx,
                               @Param("content") String content,
                               @Param("hash") String contentHash,
                               @Param("embeddingLiteral") String embeddingLiteral);

    /**
     * Vector similarity search with optional instrument / portfolio filtering.
     * Pass empty arrays to ignore a filter.
     *
     * Notes:
     * - Uses embedding <=> query_vector for cosine distance (pgvector default).
     * - Joins documents so RagService can access c.getDocument() later (requires proper @ManyToOne mapping in RagChunk).
     */
    @Query(value = """
        select c.*
        from rag_chunks c
        join rag_documents d on d.doc_id = c.doc_id
        where
          ( :instLen = 0
            or exists (select 1 from unnest(d.instrument_int_ids) x where x = any(:inst)) )
          and
          ( :pfLen = 0
            or exists (select 1 from unnest(d.portfolio_int_ids) y where y = any(:pfs)) )
        order by c.embedding <=> (:qVec)::vector
        limit :top
    """, nativeQuery = true)
    List<RagChunk> search(@Param("qVec") String qVecLiteral,
                          @Param("inst") Integer[] inst,
                          @Param("pfs") Integer[] pfs,
                          @Param("instLen") int instLen,
                          @Param("pfLen") int pfLen,
                          @Param("top") int top);
}
