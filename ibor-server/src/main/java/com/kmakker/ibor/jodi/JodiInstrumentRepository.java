package com.kmakker.ibor.jodi;

import com.kmakker.ibor.model.instrument.Instrument;
import com.kmakker.ibor.model.instrument.InstrumentFactory;
import org.jooq.DSLContext;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.Optional;

@Repository
public class JodiInstrumentRepository {
    private final DSLContext dslContext;

    public JodiInstrumentRepository(DSLContext dslContext) {
        this.dslContext = dslContext;
    }

    public  Optional<Instrument> findByCodeAsOf(String instrumentCode, LocalDate asOfDate) {
        final String sql = """
            WITH args as (
                SELECT ?::text AS instrument_code, ?::date AS as_of_date
            )
            SELECT
                v.instrument_vid,
                v.instrument_code,
                v.instrument_type,
                v.instrument_name,
                v.exchange_code,
                v.currency_code,
                v.valid_from,
                v.valid_to,
                v.maturity_date,
                v.coupon_rate,
                v.futures_expiry_date,
                v.contract_size,
                v.option_expiry_date,
                v.strike_price,
                v.option_type,
                v.multiplier,
                v.underlying_symbol
            FROM ibor.vw_instrument v, args
           WHERE v.instrument_code = args.instrument_code
             AND v.valid_from <= args.as_of_date
             AND v.valid_to >= args.as_of_date
         ORDER BY v.valid_from DESC
         LIMIT 1
        """;
        return dslContext.resultQuery(sql, instrumentCode, asOfDate)
                .fetchOptional(InstrumentFactory::fromRecord);
    }
}
