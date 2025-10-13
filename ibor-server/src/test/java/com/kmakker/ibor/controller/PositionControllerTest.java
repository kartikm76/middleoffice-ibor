package com.kmakker.ibor.controller;

import com.kmakker.ibor.dto.PositionDTO;
import com.kmakker.ibor.service.PositionService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.http.MediaType;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(controllers = PositionController.class)
class PositionControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private PositionService positionService;

    // dto returns a single position
    @Test
    void getPositions_returnOkWithBodyAndContractHeader() throws Exception {
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

        // service method is mocked to return the dto (defined above)
        when(positionService.getPositions(
                any(), any(), any(), any()
        )).thenReturn(List.of(dto));

        // this controller internally calls the positionService which has been mocked above using @MockBean
        mockMvc.perform(get("/api/positions")
                        .param("asOf", "2025-01-02")
                        .param("portfolioCode", "P-ALPHA"))
                .andExpect(status().isOk())
                .andExpect(header().string("x-contract-version", "1"))
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$[0].asOf").value("2025-01-02"))
                .andExpect(jsonPath("$[0].portfolioId").value("P-ALPHA"))
                .andExpect(jsonPath("$[0].instrumentId").value("EQ-IBM"))
                .andExpect(jsonPath("$[0].instrumentType").value("EQUITY"))
                .andExpect(jsonPath("$[0].netQty").value(100))
                .andExpect(jsonPath("$[0].price").value(150.25))
                .andExpect(jsonPath("$[0].priceSource").value("BBG"))
                .andExpect(jsonPath("$[0].mktValue").value(15025.00))
                .andExpect(jsonPath("$[0].currency").value("USD"))
                .andExpect(jsonPath("$[0].contractMultiplier").value(1));
    }
}




