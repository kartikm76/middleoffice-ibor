package com.kmakker.ibor.model.instrument;

import java.time.LocalDate;
import java.util.Optional;

public sealed interface Instrument permits Bond, Equity, Futures, Options, FX, Other {
    String instrumentCode();
    String instrumentType();
    Optional<String> instrumentName();
    Optional<String> exchangeCode();
    Optional<String> currencyCode();
    LocalDate validFrom();
    LocalDate validTo();
}
