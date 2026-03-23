package com.kmakker.ibor.service;

import com.kmakker.ibor.dto.PositionSummaryDTO;
import com.kmakker.ibor.jodi.JodiPositionCompositionRepository;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.Mockito.when;

public class PositionCompositionServiceTest {

    @Test
    void getComposition_returns_positions() {
       var repo = Mockito.mock(JodiPositionCompositionRepository.class);
       var service = new PositionCompositionService(repo);

       var dto = new PositionSummaryDTO(
               LocalDate.now(), "ALPHA", "IBM", "EQUITY",
               BigDecimal.TEN, BigDecimal.valueOf(100), "BBG",
               BigDecimal.valueOf(1000), "USD");

       when(repo.findComposition(
               Mockito.any(),
               Mockito.any(),
               Mockito.any(),
               Mockito.anyInt())).
       thenReturn(List.of(dto));

       var result = service.getComposition(LocalDate.now(), "ALPHA", 1, 50);
       assertNotNull(result);
       assertEquals(1, result.size());
       assertEquals("ALPHA", result.getFirst().portfolioCode());
       assertEquals("IBM", result.getFirst().instrumentCode());
       assertEquals("EQUITY", result.getFirst().instrumentType());
       assertEquals(BigDecimal.TEN, result.getFirst().netQty());
       assertEquals(BigDecimal.valueOf(100), result.getFirst().price());
       assertEquals(BigDecimal.valueOf(1000), result.getFirst().mktValue());
       assertEquals("USD", result.getFirst().currency());
    }

}
