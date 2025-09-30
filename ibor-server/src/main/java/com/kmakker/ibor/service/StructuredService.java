package com.kmakker.ibor.service;

import com.kmakker.ibor.domain.Instrument;
import com.kmakker.ibor.repositories.CashEventRepository;
import com.kmakker.ibor.repositories.InstrumentRepository;
import com.kmakker.ibor.repositories.PortfolioRepository;
import com.kmakker.ibor.repositories.TradeRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.*;

/**
 * Structured (relational) finance facts service:
 * - aggregate position (qty/side/MV) by instrument + optional portfolio filters
 * - by-portfolio position breakdown
 * - cash projection over a horizon
 *
 * NOTE: Methods return Map payloads to keep controllers simple; your controllers map to DTOs.
 */
@Slf4j
@Service
public class StructuredService {

    private final InstrumentRepository instruments;
    private final PortfolioRepository portfolios;
    private final TradeRepository trades;
    private final CashEventRepository cashEvents;

    public StructuredService(InstrumentRepository instruments,
                             PortfolioRepository portfolios,
                             TradeRepository trades,
                             CashEventRepository cashEvents) {
        this.instruments = instruments;
        this.portfolios = portfolios;
        this.trades = trades;
        this.cashEvents = cashEvents;
    }

    /**
     * Get aggregate position facts for an instrument, optionally filtered by portfolio codes.
     * @param tickerOrId instrument ticker (e.g., "IBM") OR numeric id as string (e.g., "12")
     * @param portfolioCodes optional list of portfolio codes (e.g., ["ALPHA","GM"]); null/empty = all
     */
    public Map<String, Object> getPositionAggregate(String tickerOrId, List<String> portfolioCodes) {
        Integer instrumentId = resolveInstrumentId(tickerOrId);
        Instrument inst = instruments.findById(instrumentId)
                .orElseThrow(() -> new IllegalArgumentException("Unknown instrument id: " + instrumentId));

        // Optional portfolio filter: convert codes -> int ids (TradeRepository expects ids list or null)
        List<Integer> pfIds = resolvePortfolioIds(portfolioCodes);

        BigDecimal qtyBD = trades.netQty(instrumentId, pfIds == null || pfIds.isEmpty() ? null : pfIds);
        double qty = qtyBD == null ? 0d : qtyBD.doubleValue();
        String side = qty > 0 ? "LONG" : (qty < 0 ? "SHORT" : "FLAT");

        log.info("Instrument ID: " + inst.getId());

        double px = Optional.ofNullable(inst.getPriceLast())
                .map(BigDecimal::doubleValue)
                .orElse(0d);
        double mv = px * qty;

        Map<String, Object> price = new LinkedHashMap<>();
        price.put("price_last", inst.getPriceLast());
        price.put("currency", inst.getCurrency());
        price.put("price_time", inst.getPriceTime());

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("instrument_id", instrumentId);
        out.put("ticker", inst.getTicker());
        out.put("qty", qty);
        out.put("side", side);
        out.put("market_value", mv);
        out.put("price", price);
        return out;
    }

    /**
     * Position by portfolio for an instrument (no portfolio filter).
     * @param tickerOrId instrument ticker or numeric id as string
     */
    public List<Map<String, Object>> byPortfolio(String tickerOrId) {
        Integer instrumentId = resolveInstrumentId(tickerOrId);
        var rows = trades.byPortfolio(instrumentId);

        List<Map<String, Object>> out = new ArrayList<>();
        for (var r : rows) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("portfolio_id", r.getPortfolioId());
            m.put("qty", r.getQty());
            out.add(m);
        }
        return out;
    }

    /**
     * Cash projection aggregated by portfolio/ccy/value date over the next N days.
     * Controller maps the result to CashRowDTO.
     */
    public List<Map<String, Object>> cashProjection(List<String> portfolioCodes, int days) {
        LocalDate maxDate = LocalDate.now().plusDays(days);
        // Repository filters by portfolio CODE (human-readable). Null list = no filter.
        var rows = cashEvents.project(
                (portfolioCodes == null || portfolioCodes.isEmpty()) ? null : portfolioCodes,
                maxDate
        );

        List<Map<String, Object>> out = new ArrayList<>();
        for (var r : rows) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("portfolio_id", r.getPortfolioId());  // int PK
            m.put("ccy", r.getCcy());
            m.put("value_dt", r.getValueDt());
            m.put("net", r.getNet());
            m.put("drivers", List.of()); // placeholder; add if/when you track drivers
            out.add(m);
        }
        return out;
    }

    // -----------------------
    // Helpers
    // -----------------------

    /** Accepts ticker (e.g., "IBM") or numeric id represented as String (e.g., "12"). */
    private Integer resolveInstrumentId(String tickerOrId) {
        // Numeric id?
        try {
            return Integer.valueOf(tickerOrId);
        } catch (NumberFormatException ignore) {
            // Not a number: must be ticker
        }
        return instruments.findIdByTicker(tickerOrId)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND,
                        "Instrument not found: " + tickerOrId
                ));
    }

    /** Convert portfolio codes -> int ids (used for trade filtering); returns empty list if none. */
    private List<Integer> resolvePortfolioIds(List<String> portfolioCodes) {
        if (portfolioCodes == null || portfolioCodes.isEmpty()) return List.of();
        List<Integer> ids = new ArrayList<>(portfolioCodes.size());
        for (String code : portfolioCodes) {
            Integer id = portfolios.findIdByCode(code)
                    .orElseThrow(() -> new ResponseStatusException(
                            HttpStatus.NOT_FOUND,
                            "Portfolio not found: " + code
                    ));
            ids.add(id);
        }
        return ids;
    }

    /** Utility for controllers that need a timestamp. */
    public static OffsetDateTime nowUtc() {
        return OffsetDateTime.now(ZoneOffset.UTC);
    }
}