package com.kmakker.ibor.service;

import com.kmakker.ibor.domain.RagChunk;
import com.kmakker.ibor.domain.RagDocument;
import com.kmakker.ibor.repositories.InstrumentRepository;
import com.kmakker.ibor.repositories.PortfolioRepository;
import com.kmakker.ibor.repositories.RagChunkRepository;
import com.kmakker.ibor.repositories.RagDocumentRepository;
import dev.langchain4j.data.embedding.Embedding;
import dev.langchain4j.model.openai.OpenAiEmbeddingModel;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.*;

@Service
public class RagService {

    private final RagDocumentRepository docs;
    private final RagChunkRepository chunks;
    private final InstrumentRepository instruments;
    private final PortfolioRepository portfolios;

    private final int chunkChars;
    private final int chunkOverlap;
    private final int topK;

    /** Responsibility: convert text -> embedding (sync). */
    private final OpenAiEmbeddingModel embedModel;

    public RagService(RagDocumentRepository docs,
                      RagChunkRepository chunks,
                      InstrumentRepository instruments,
                      PortfolioRepository portfolios,
                      @Value("${OPENAI_API_KEY:${openai.api-key:}}") String openAiApiKey,
                      @Value("${rag.chunkChars:1200}") int chunkChars,
                      @Value("${rag.chunkOverlap:120}") int chunkOverlap,
                      @Value("${rag.topK:6}") int topK) {
        this.docs = docs;
        this.chunks = chunks;
        this.instruments = instruments;
        this.portfolios = portfolios;
        if (openAiApiKey == null || openAiApiKey.isBlank()) {
            openAiApiKey = System.getenv("OPENAI_API_KEY");
        }
        if (openAiApiKey == null || openAiApiKey.isBlank()) {
            throw new IllegalStateException("OpenAI API key not configured. Set OPENAI_API_KEY env var or 'openai.api-key' in application.properties.");
        }
        this.chunkChars = chunkChars;
        this.chunkOverlap = chunkOverlap;
        this.topK = topK;
        this.embedModel = OpenAiEmbeddingModel.builder()
                .apiKey(openAiApiKey)
                .modelName("text-embedding-3-small")
                .build();
    }

    private static String sha256(String s) {
        try {
            var md = MessageDigest.getInstance("SHA-256");
            byte[] dig = md.digest(s.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : dig) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (Exception e) { throw new RuntimeException(e); }
    }

    /**
     * Ingest a free-form note (synchronous, MVC-friendly):
     *  1) Resolve instrument/portfolio IDs
     *  2) Embed full text using LangChain4j
     *  3) Save document + single chunk with embedding (pgvector literal)
     */
    public Map<String,Object> ingestNoteFromAliases(String title,
                                                    String author,
                                                    String text,
                                                    List<String> instrumentTickers,
                                                    List<String> portfolioCodes) {

        // 1) Resolve lookups
        List<Integer> instIds = resolveInstrumentIds(instrumentTickers);
        List<Integer> pfIds   = resolvePortfolioIds(portfolioCodes);

        // 2) Embed text
        String vecLiteral = embedAsPgVectorLiteral(text);

        // 3) Persist doc + chunk
        UUID docId = saveDocumentAndChunk(title, author, text, instIds, pfIds, vecLiteral);

        return Map.of("docId", docId.toString(), "chunks", 1);
    }

    @Transactional
    protected UUID saveDocumentAndChunk(String title, String author, String text,
                                        List<Integer> instIds, List<Integer> pfIds,
                                        String vecLiteral) {
        // document
        RagDocument doc = new RagDocument();
        doc.setDocId(UUID.randomUUID());              // entity uses UUID
        doc.setTitle(title);
        doc.setAuthor(author);
        doc.setSourceType("NOTE");
        doc.setSourceUri("note:" + doc.getDocId());
        doc.setCreatedAt(OffsetDateTime.now(ZoneOffset.UTC));
        doc.setUpdatedAt(OffsetDateTime.now(ZoneOffset.UTC));
        doc.setInstrumentIntIds(instIds == null ? new Integer[]{} : instIds.toArray(Integer[]::new));
        doc.setPortfolioIntIds(pfIds == null ? new Integer[]{} : pfIds.toArray(Integer[]::new));
        doc.setMeta("{}");                            // keep meta as empty JSON string
        docs.save(doc);

        // chunk (native insert ensures (::vector) cast)
        chunks.insertChunkWithVector(
                doc.getDocId(),
                0,
                text,
                sha256(text),
                vecLiteral
        );

        return doc.getDocId();
    }

    @Transactional(readOnly = true)
    public List<Map<String,Object>> search(String query,
                                           List<Integer> instrumentIds,
                                           List<Integer> portfolioIds,
                                           Integer k) {
        int top = (k == null || k <= 0) ? this.topK : k;

        // Build query embedding (sync)
        String qVecLiteral = embedAsPgVectorLiteral(query);

        Integer[] inst = (instrumentIds == null || instrumentIds.isEmpty())
                ? new Integer[]{} : instrumentIds.toArray(Integer[]::new);
        Integer[] pfs  = (portfolioIds == null || portfolioIds.isEmpty())
                ? new Integer[]{} : portfolioIds.toArray(Integer[]::new);

        int instLen = inst.length;
        int pfLen = pfs.length;

        List<RagChunk> list = chunks.search(qVecLiteral, inst, pfs, instLen, pfLen, top);

        List<Map<String,Object>> out = new ArrayList<>(list.size());
        for (RagChunk c : list) {
            RagDocument d = c.getDocument(); // requires @ManyToOne mapping in RagChunk
            out.add(Map.of(
                    "doc_id", d.getDocId(),
                    "title", d.getTitle(),
                    "source_uri", d.getSourceUri(),
                    "author", d.getAuthor(),
                    "updated_at", d.getUpdatedAt(),
                    "chunk_idx", c.getChunkIdx(),
                    "content", c.getContent()
            ));
        }
        return out;
    }

    /** Convert text to pgvector literal via LangChain4j (simple & synchronous). */
    private String embedAsPgVectorLiteral(String text) {
        Embedding emb = embedModel.embed(text).content();
        float[] vec = emb.vector();     // LangChain4j returns a primitive array here
        int n = vec.length;              // arrays use `.length`, not `.length()`
        StringBuilder sb = new StringBuilder(n * 10);
        sb.append('[');
        for (int i = 0; i < n; i++) {
            if (i > 0) sb.append(',');
            sb.append(vec[i]);           // array indexing instead of `.get(i)`
        }
        sb.append(']');
        return sb.toString();
    }

    // Optional: kept for future multi-chunk support
    private List<String> chunk(String text) {
        List<String> out = new ArrayList<>();
        if (text == null || text.isBlank()) return out;
        int n = text.length(), start = 0;
        while (start < n) {
            int end = Math.min(n, start + chunkChars);
            int p = text.lastIndexOf("\n\n", end);
            if (p > start + 200) end = p;
            out.add(text.substring(start, end).trim());
            start = Math.max(end - chunkOverlap, end);
        }
        return out;
    }

    private List<Integer> resolveInstrumentIds(List<String> tickers) {
        if (tickers == null || tickers.isEmpty()) return List.of();
        return tickers.stream()
                .map(t -> instruments.findByTicker(t)
                        .orElseThrow(() -> new IllegalArgumentException("Unknown ticker: " + t))
                        .getId())
                .toList();
    }

    private List<Integer> resolvePortfolioIds(List<String> codes) {
        if (codes == null || codes.isEmpty()) return List.of();
        return codes.stream()
                .map(c -> portfolios.findByCode(c)
                        .orElseThrow(() -> new IllegalArgumentException("Unknown portfolio: " + c))
                        .getId())
                .toList();
    }
}