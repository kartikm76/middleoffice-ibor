package com.kmakker.ibor.integration;

import com.kmakker.ibor.IborApplication;
import com.kmakker.ibor.dto.PositionDTO;
import com.kmakker.ibor.jodi.JodiPositionsRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@SpringBootTest(
        classes = IborApplication.class,
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = "spring.profiles.active=test"
)
public class PositionIntegrationTest {
    @LocalServerPort
    private int port;

    @Autowired
    private TestRestTemplate restTemplate;

    @MockitoBean
    private JodiPositionsRepository positionsRepository;

    @Test
    void getPositions_returnOkWithBodyAndContractHeader() {
        String baseUrl = "http://localhost:" + port + "/api/positions?asOf=2025-01-02&portfolioCode=P-ALPHA";

        // Stub repository to avoid real DB dependency
        var dto = new PositionDTO(
                LocalDate.parse("2025-01-02"),
                "P-ALPHA",
                "EQ-IBM",
                "EQUITY",
                new BigDecimal("100"),
                new BigDecimal("150.25"),
                "BBG",
                new BigDecimal("15025.00"),
                null,
                null,
                "USD",
                BigDecimal.ONE
        );
        when(positionsRepository.findPositions(
                    eq(LocalDate.parse("2025-01-02")),
                    eq("P-ALPHA"),
                    anyInt(),
                    anyInt()))
                .thenReturn(List.of(dto));

        ResponseEntity<PositionDTO[]> response =
                restTemplate.getForEntity(baseUrl, PositionDTO[].class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getHeaders().getFirst("x-contract-version")).isEqualTo("1");
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().length).isGreaterThanOrEqualTo(1);
        assertThat(response.getBody()[0].instrumentId()).isEqualTo("EQ-IBM");
    }
}
