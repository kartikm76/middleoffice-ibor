package com.kmakker.ibor.controller;

import com.kmakker.ibor.dto.IngestNoteRequest;
import com.kmakker.ibor.service.RagService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@Tag(name = "Notes")
@RestController
@RequestMapping("/api/notes")
public class NotesController {

    private final RagService rag;

    public NotesController(RagService rag) {
        this.rag = rag;
    }

    @PostMapping("/ingest")
    public Map<String, Object> ingest(@Valid @RequestBody IngestNoteRequest body) {
        return rag.ingestNoteFromAliases(
                body.title(),
                body.author(),
                body.text(),
                body.instrumentTickers(),
                body.portfolioCodes()
        );
    }
}