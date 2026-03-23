package com.kmakker.ibor.jodi;

import com.kmakker.ibor.dto.PriceRowDTO;
import org.jooq.DSLContext;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Repository
public class JodiPriceRepository {
    private final DSLContext dslContext;

    public JodiPriceRepository(DSLContext dslContext) {
        this.dslContext = dslContext;
    }

    public List<PriceRowDTO> findPrices(String instrumentCode,
                                        LocalDate from_dt,
                                        LocalDate to_dt,
                                        String source) {

        String sql = """
          WITH args AS (
               SELECT ?::text AS instrument_code,
                      ?::date AS from_dt,
                      ?::date AS to_dt,
                      ?::text AS source_code
           ),
           i AS (
               SELECT di.instrument_vid
               FROM ibor.dim_instrument di, args
               WHERE di.instrument_code = args.instrument_code
                 AND di.valid_from <= args.to_dt AND di.valid_to >= args.to_dt
               LIMIT 1
           )
           SELECT fp.price_ts,
                  fp.price,
                  fp.currency_code,
                  dps.price_source_code
           FROM ibor.fact_price fp
           JOIN i ON fp.instrument_vid = i.instrument_vid
           JOIN ibor.dim_price_source dps ON dps.price_source_vid = fp.price_source_vid
           JOIN args ON TRUE
           WHERE fp.price_ts BETWEEN args.from_dt AND (args.to_dt + time '23:59:59')
             AND (args.source_code IS NULL OR dps.price_source_code = args.source_code)
           ORDER BY fp.price_ts ASC
        """;

        return dslContext.fetch(sql, instrumentCode, from_dt, to_dt, source)
                .stream()
                .map(record -> new PriceRowDTO(
                        record.get("price_ts", java.time.OffsetDateTime.class).toInstant(),
                        record.get("price", BigDecimal.class),
                        record.get("currency_code", String.class),
                        record.get("price_source_code", String.class)
                ))
                .toList();
    }
}
