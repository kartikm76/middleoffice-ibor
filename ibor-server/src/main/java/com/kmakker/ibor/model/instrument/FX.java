package com.kmakker.ibor.model.instrument;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;

public record FX (
    String instrumentCode,
    String instrumentType,
    Optional<String> instrumentName,
    Optional<String> exchangeCode,
    Optional<String> currencyCode,
    LocalDate validFrom,
    LocalDate validTo,
    Optional<String> fromCurrency,
    Optional<String> toCurrency,
    Optional<BigDecimal> rate
) implements Instrument {}
