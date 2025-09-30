package com.kmakker.ibor.ai;

import dev.langchain4j.agent.tool.Tool;
import org.springframework.stereotype.Component;
import com.kmakker.ibor.service.RagService;
import com.kmakker.ibor.repositories.InstrumentRepository;
import com.kmakker.ibor.repositories.PortfolioRepository;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Component
public class NoteRetrievalTool {

    private final RagService rag;
    private final InstrumentRepository instruments;
    private final PortfolioRepository portfolios;

    public NoteRetrievalTool(RagService rag, InstrumentRepository instruments, PortfolioRepository portfolios) {
        this.rag = rag;
        this.instruments = instruments;
        this.portfolios = portfolios;
    }

    @Tool("Search PM notes for a question/instrument with optional portfolios; returns a list of passages with title, author, updatedAt, content. " +
            "Args: question (string), instrumentTicker (string), portfolioCodes (array of strings), topK (int).")
    public List<Map<String, Object>> searchNotes(String question, String instrumentTicker, List<String> portfolioCodes, int topK) {
        var instId = instruments.findByTicker(instrumentTicker)
                .map(i -> i.getId())
                .orElseThrow(() -> new IllegalArgumentException("Unknown ticker: " + instrumentTicker));
        List<Integer> pfIds = new ArrayList<>();
        if (portfolioCodes != null) {
            for (String code : portfolioCodes) {
                var pid = portfolios.findByCode(code)
                        .map(p -> p.getId())
                        .orElseThrow(() -> new IllegalArgumentException("Unknown portfolio code: " + code));
                pfIds.add(pid);
            }
        }
        return rag.search(question, List.of(instId), pfIds, topK <= 0 ? 6 : topK);
    }
}