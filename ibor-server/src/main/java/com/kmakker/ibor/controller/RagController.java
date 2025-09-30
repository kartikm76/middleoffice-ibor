package com.kmakker.ibor.controller;

import com.kmakker.ibor.ai.Assistant;
import com.kmakker.ibor.dto.ContextDTO;
import com.kmakker.ibor.dto.HybridAnswerResponse;
import com.kmakker.ibor.dto.HybridAskRequest;
import com.kmakker.ibor.dto.PositionAggregateDTO;
import com.kmakker.ibor.dto.PriceDTO;
import com.kmakker.ibor.repositories.InstrumentRepository;
import com.kmakker.ibor.repositories.PortfolioRepository;
import com.kmakker.ibor.service.RagService;
import com.kmakker.ibor.service.StructuredService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

import java.util.stream.Collectors;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.*;

@Tag(name = "RAG")
@RestController
@RequestMapping("/api/rag")
public class RagController {

    private final RagService rag;
    private final StructuredService structured;
    private final Assistant assistant;
    private final InstrumentRepository instruments;
    private final PortfolioRepository portfolios;

    public RagController(RagService rag,
                         StructuredService structured,
                         Assistant assistant,
                         InstrumentRepository instruments,
                         PortfolioRepository portfolios) {
        this.rag = rag;
        this.structured = structured;
        this.assistant = assistant;
        this.instruments = instruments;
        this.portfolios = portfolios;
    }

    @PostMapping("/hybrid")
    public HybridAnswerResponse hybrid(@Valid @RequestBody HybridAskRequest req) {
        Integer instrumentId = instruments.findByTicker(req.instrumentTicker())
                .map(i -> i.getId())
                .orElseThrow(() -> new IllegalArgumentException("Unknown ticker: " + req.instrumentTicker()));

        List<Integer> pfIds = new ArrayList<>();
        if (req.portfolioCodes() != null) {
            for (String code : req.portfolioCodes()) {
                Integer pid = portfolios.findByCode(code)
                        .map(p -> p.getId())
                        .orElseThrow(() -> new IllegalArgumentException("Unknown portfolio code: " + code));
                pfIds.add(pid);
            }
        }

        Map<String, Object> facts = structured.getPositionAggregate(req.instrumentTicker(), req.portfolioCodes());
        PositionAggregateDTO factsDto = new PositionAggregateDTO(
                ((Number) facts.get("instrument_id")).intValue(),
                (String) facts.getOrDefault("ticker", req.instrumentTicker()),
                ((Number) facts.get("qty")).doubleValue(),
                (String) facts.get("side"),
                ((Number) facts.get("market_value")).doubleValue(),
                mapPrice((Map<String, Object>) facts.get("price"))
        );

        var ctxRows = rag.search(req.question(), List.of(instrumentId), pfIds, req.topK());
        List<ContextDTO> ctxs = ctxRows.stream().map(r -> new ContextDTO(
                (UUID) r.get("doc_id"),
                (String) r.get("title"),
                (String) r.get("source_uri"),
                (String) r.get("author"),
                (java.time.OffsetDateTime) r.get("updated_at"),
                ((Number) r.get("chunk_idx")).intValue(),
                (String) r.get("content")
        )).toList();

        int ctxCount = ctxs.size();
        var now = java.time.OffsetDateTime.now();
        boolean stale = ctxs.stream()
                .filter(c -> c.updatedAt() != null)
                .allMatch(c -> c.updatedAt().isBefore(now.minusDays(30)));

        StringBuilder gapHints = new StringBuilder();
        if (ctxCount == 0) gapHints.append("No PM notes matched this instrument/portfolio filter. ");
        if (ctxCount == 1) gapHints.append("Only a single relevant note was found. ");
        if (stale) gapHints.append("All notes are older than 30 days. ");

        String dataGaps = gapHints.isEmpty() ? "none" : gapHints.toString().trim();

        // Keep facts as a compact blob; model must treat it as source of truth for numbers
        String structuredBlob = facts.toString();

        // Build a readable CONTEXT from the retrieved chunks (title + updatedAt + content)
        // NOTE: we use the already-built `ctxs` list (List<ContextDTO>) so we don't touch lazy proxies here.
        String contextBlob = ctxs.stream()
                .map(c -> String.format("Title: %s | Updated: %s%n%s",
                        (c.title() == null || c.title().isBlank()) ? c.sourceUri() : c.title(),
                        c.updatedAt(),
                        c.content()))
                .collect(Collectors.joining("\n\n"));

        String answer = assistant.chat(
                req.question() + "\n\n" +
                "STRUCTURED=\n" + structuredBlob + "\n\n" +
                "CONTEXT=\n" + contextBlob + "\n\n" +
                "GAPS=\n" + dataGaps
        );

        return new HybridAnswerResponse(answer, factsDto, ctxs, OffsetDateTime.now(ZoneOffset.UTC));
    }

    private static PriceDTO mapPrice(Map<String, Object> price) {
        if (price == null) return new PriceDTO(null, null, null);
        return new PriceDTO(
                (BigDecimal) price.get("price_last"),
                (String) price.get("currency"),
                (java.time.OffsetDateTime) price.get("price_time")
        );
    }
}