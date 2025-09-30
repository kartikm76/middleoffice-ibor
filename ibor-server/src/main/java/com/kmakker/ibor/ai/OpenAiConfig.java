// src/main/java/com/kmakker/ibor/ai/OpenAiConfig.java
package com.kmakker.ibor.ai;

import dev.langchain4j.service.AiServices;
import dev.langchain4j.model.chat.ChatModel;
import dev.langchain4j.model.openai.OpenAiChatModel;
import dev.langchain4j.model.openai.OpenAiEmbeddingModel;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.info.Info;

@OpenAPIDefinition(
        info = @Info(
                title = "IBOR Hybrid RAG API",
                version = "1.0",
                description = "Structured facts + RAG vector search + LLM composition"
        )
)

@Configuration
public class OpenAiConfig {

    @Bean
    ChatModel chatModel(
            @Value("${openai.api-key:${OPENAI_API_KEY:}}") String apiKey,
            @Value("${openai.baseUrl:https://api.openai.com/v1}") String baseUrl,
            @Value("${openai.chatModel:gpt-4o-mini}") String model
    ) {
        if (apiKey == null || apiKey.isBlank()) {
            throw new IllegalStateException("OpenAI API key not configured (openai.api-key or OPENAI_API_KEY).");
        }
        return OpenAiChatModel.builder()
                .apiKey(apiKey)
                .baseUrl(baseUrl)      // must include /v1
                .modelName(model)
                .build();
    }

    @Bean
    OpenAiEmbeddingModel embeddingModel(
            @Value("${openai.api-key:${OPENAI_API_KEY:}}") String apiKey,
            @Value("${openai.baseUrl:https://api.openai.com/v1}") String baseUrl,
            @Value("${openai.embedModel:text-embedding-3-small}") String model
    ) {
        if (apiKey == null || apiKey.isBlank()) {
            throw new IllegalStateException("OpenAI API key not configured (openai.api-key or OPENAI_API_KEY).");
        }
        return OpenAiEmbeddingModel.builder()
                .apiKey(apiKey)
                .baseUrl(baseUrl)      // must include /v1
                .modelName(model)
                .build();
    }

    @Bean
    Assistant assistant(ChatModel chatModel, PositionTools tools) {
        return AiServices.builder(Assistant.class)
                .chatModel(chatModel)  // ChatModel for 1.4.0
                .tools(tools)
                .build();
    }
}