package com.kmakker.ibor.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record CashRowDTO(
    int portfolioId,
    String ccy,
    LocalDate valueDt,
    BigDecimal net,
    List<String> drivers
) {}
