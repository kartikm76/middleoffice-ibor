package com.kmakker.ibor.jodi;

import com.kmakker.ibor.dto.FxRateDTO;
import org.jooq.DSLContext;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Repository
public class JodiFxRateRepository {
    private final DSLContext dslContext;

    public JodiFxRateRepository(DSLContext dslContext) {
        this.dslContext = dslContext;
    }

    /**
     * Fetch raw FX rates for a direct currency pair over a date range.
     * No inversion or triangulation here — callers handle that in the service layer.
     */
    public List<FxRateDTO> findFxRates(String fromCurrency,
                                       String toCurrency,
                                       LocalDate fromDate,
                                       LocalDate toDate) {

        final String sql = """
                WITH args AS (
                    SELECT ?::text  AS from_ccy,
                           ?::text  AS to_ccy,
                           ?::date  AS from_dt,
                           ?::date  AS to_dt
                )
                SELECT f.rate_date,
                       f.rate,
                       f.from_currency_code,
                       f.to_currency_code
                  FROM ibor.fact_fx_rate f, args
                 WHERE f.from_currency_code = args.from_ccy
                   AND f.to_currency_code   = args.to_ccy
                   AND f.rate_date BETWEEN args.from_dt AND args.to_dt
                 ORDER BY f.rate_date
                """;

        return dslContext.resultQuery(sql, fromCurrency, toCurrency, fromDate, toDate)
                .fetch(record -> new FxRateDTO(
                        record.get("rate_date", LocalDate.class),
                        record.get("from_currency_code", String.class),
                        record.get("to_currency_code", String.class),
                        record.get("rate", BigDecimal.class)
                ));
    }

    /**
     * Convenience: fetch both directions (A->B and B->A) in one round trip.
     * Still “raw”; the service decides what to do with each leg.
     */
    public List<FxRateDTO> findFxRatesBothDirections(String ccyA,
                                                     String ccyB,
                                                     LocalDate fromDate,
                                                     LocalDate toDate) {

        final String sql = """
                WITH args AS (
                    SELECT ?::text AS ccy_a,
                           ?::text AS ccy_b,
                           ?::date AS from_dt,
                           ?::date AS to_dt
                )
                SELECT f.rate_date,
                       f.rate,
                       f.from_currency_code,
                       f.to_currency_code
                  FROM ibor.fact_fx_rate f, args
                 WHERE (f.from_currency_code = args.ccy_a AND f.to_currency_code = args.ccy_b)
                    OR (f.from_currency_code = args.ccy_b AND f.to_currency_code = args.ccy_a)
                   AND f.rate_date BETWEEN args.from_dt AND args.to_dt
                 ORDER BY f.rate_date, f.from_currency_code, f.to_currency_code
                """;

        return dslContext.resultQuery(sql, ccyA, ccyB, fromDate, toDate)
                .fetch(record -> new FxRateDTO(
                        record.get("rate_date", LocalDate.class),
                        record.get("from_currency_code", String.class),
                        record.get("to_currency_code", String.class),
                        record.get("rate", BigDecimal.class)
                ));
    }
}
          
          
