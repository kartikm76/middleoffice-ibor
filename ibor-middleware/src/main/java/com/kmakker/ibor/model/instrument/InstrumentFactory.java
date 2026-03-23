package com.kmakker.ibor.model.instrument;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Locale;
import java.util.Optional;
import org.jooq.Record;

public final class InstrumentFactory {
    private InstrumentFactory() {}

    public static Instrument fromRecord(Record r) {
        String instrumentType = opt(r, "instrument_type", String.class).orElse("OTHER").toUpperCase(Locale.ROOT);

        // common
        String instrumentCode = req(r, "instrument_code", String.class);
        Optional<String> instrumentName = opt(r, "instrument_name", String.class);
        Optional<String> exchangeCode = opt(r, "exchange_code", String.class);
        Optional<String> currencyCode = opt(r, "currency_code", String.class);
        LocalDate validFrom = req(r, "valid_from", LocalDate.class);
        LocalDate validTo = req(r, "valid_to", LocalDate.class);

        switch (instrumentType) {
            case "EQUITY" -> {
                return new Equity(instrumentCode, instrumentType, instrumentName, exchangeCode, currencyCode, validFrom, validTo);
            }
            case "BOND" -> {
                Optional<LocalDate> maturityDate = opt(r, "maturity_date", LocalDate.class);
                Optional<BigDecimal> couponRate = opt(r, "coupon_rate", BigDecimal.class);
                return new Bond(instrumentCode, instrumentType, instrumentName, exchangeCode, currencyCode, validFrom, validTo, maturityDate, couponRate);
            }
            case "FUTURES" -> {
                Optional<LocalDate> futuresExpiryDate = opt(r, "futures_expiry_date", LocalDate.class);
                Optional<Integer> contractSize = opt(r, "contract_size", Integer.class);
                return new Futures(instrumentCode, instrumentType, instrumentName, exchangeCode, currencyCode, validFrom, validTo, futuresExpiryDate, contractSize);
            }
            case "OPTIONS" -> {
                Optional<String> optionSymbol = opt(r, "option_symbol", String.class);
                Optional<String> underlyingSymbol = opt(r, "underlying_symbol", String.class);
                Optional<String> optionType = opt(r, "option_type", String.class);
                Optional<Integer> strikePrice = opt(r, "strike_price", Integer.class);
                Optional<LocalDate> optionsExpiryDate = opt(r, "options_expiry_date", LocalDate.class);
                Optional<Integer> optionsStrikePrice = opt(r, "options_strike_price", Integer.class);
                return new Options(instrumentCode, instrumentType, instrumentName, exchangeCode, currencyCode, validFrom, validTo,
                                    optionSymbol, underlyingSymbol, optionType, strikePrice, optionsExpiryDate, optionsStrikePrice);
            }
            default -> {
                return new Other(instrumentCode, instrumentType, instrumentName, exchangeCode, currencyCode, validFrom, validTo);
            }
        }
    }

    private static <T> T req(Record r, String col, Class<T> type) {
        T value = r.get(col, type);
        if (value == null) throw new IllegalArgumentException(String.format("Required column '%s' is missing", col) );
        return value;
    }

    private static <T> Optional<T> opt(Record r, String col, Class<T> type) {
        return Optional.ofNullable(r.get(col, type));
    }
}
