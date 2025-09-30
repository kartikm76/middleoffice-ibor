package com.kmakker.ibor.controller;

import com.kmakker.ibor.ai.Assistant;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/rag")
public class AssistantController {

    private final Assistant assistant;

    public AssistantController(Assistant assistant) {
        this.assistant = assistant;
    }

    public record AskBody(@NotBlank String question) {
    }

    @PostMapping("/assistant")
    public Map<String, String> ask(@Valid @RequestBody AskBody body) {
        String answer = assistant.chat(body.question());
        return Map.of("answer", answer);
    }
}