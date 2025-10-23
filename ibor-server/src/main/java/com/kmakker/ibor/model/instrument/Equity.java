package com.kmakker.ibor.model.instrument;

import java.time.LocalDate;
import java.util.Optional;

public record Equity (
        String instrumentCode,
        String instrumentType,
        Optional <String> instrumentName,
        Optional <String> exchangeCode,
        Optional <String> currencyCode,
        LocalDate validFrom,
        LocalDate validTo
) implements Instrument {}
