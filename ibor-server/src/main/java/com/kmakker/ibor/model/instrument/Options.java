package com.kmakker.ibor.model.instrument;

import org.springframework.cglib.core.Local;

import java.time.LocalDate;
import java.util.Optional;

public record Options (
    String instrumentCode,
    String instrumentType,
    Optional<String> instrumentName,
    Optional<String> exchangeCode,
    Optional<String> currencyCode,
    LocalDate validFrom,
    LocalDate validTo,
    Optional<String> optionSymbol,
    Optional<String> underlyingSymbol,
    Optional<String> optionType,
    Optional<Integer> strikePrice,
    Optional<LocalDate> expiryDate,
    Optional<Integer> multiplier
) implements Instrument {}
