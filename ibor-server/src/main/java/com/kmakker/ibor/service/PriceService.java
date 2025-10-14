package com.kmakker.ibor.service;

import com.kmakker.ibor.dto.FxRateDTO;
import com.kmakker.ibor.dto.PriceRowDTO;
import com.kmakker.ibor.jodi.JodiFxRateRepository;
import com.kmakker.ibor.jodi.JodiPriceRepository;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.*;
import java.util.stream.Collectors;

/**
 * PriceService
 *
 * <p>Responsibilities:</p>
 * <ul>
 *   <li>Fetch historical instrument prices via {@link JodiPriceRepository}</li>
 *   <li>Optionally convert those prices into a requested base currency using FX rates from
 *       {@link JodiFxRateRepository}</li>
 *   <li>Perform all FX arithmetic in-memory; repositories stay focused on data access</li>
 * </ul>
 *
 * <p>Conversion strategy (per instrument price row):</p>
 * <ol>
 *   <li>If the instrument currency already equals the requested base, return the row unchanged</li>
 *   <li>Try to build a complete date→rate map using direct or inverse pairs (src→base or base→src)</li>
 *   <li>If gaps remain for some days, triangulate via USD for those days:
 *       rate(src→base) = rate(src→USD) / rate(base→USD)</li>
 *   <li>Multiply price by rate and round to scale 8 (HALF_UP)</li>
 * </ol>
 *
 * <p>Notes:</p>
 * <ul>
 *   <li>When a rate is missing for a given day, the original row is returned (no conversion)</li>
 *   <li>Direct rates win over inverse for the same day; latest duplicate wins when reducing</li>
 *   <li>All string currencies are normalized to upper-case 3-letter codes</li>
 * </ul>
 */
@Service
public class PriceService {
    private static final String USD = "USD";

    private final JodiPriceRepository priceRepository;
    private final JodiFxRateRepository fxRateRepository;

    public PriceService(JodiPriceRepository priceRepository, JodiFxRateRepository fxRateRepository) {
        this.priceRepository = priceRepository;
        this.fxRateRepository = fxRateRepository;
    }

    /**
     * Fetch raw prices and (optionally) convert them to a base currency.
     * SQL remains purely data access; all FX math is performed here.
     *
     * @param instrumentCode instrument ticker or identifier used by the price repository
     * @param from_dt        inclusive start date (in instrument's price timeline)
     * @param to_dt          inclusive end date
     * @param maybeSource    optional price source code (e.g., "BBG"); repository decides how to apply
     * @param maybeBaseCurrency optional ISO-4217 code (e.g., "USD"). If empty, no conversion is performed
     * @return list of prices, converted to base if requested and rate available for each row's date
     */
    public List<PriceRowDTO> getPrices(String instrumentCode,
                                       LocalDate from_dt,
                                       LocalDate to_dt,
                                       String maybeSource,
                                       String maybeBaseCurrency) {

        // 1) Fetch raw instrument prices (in their native currency)
        final List<PriceRowDTO> rawPrices = priceRepository.findPrices(
                instrumentCode, from_dt, to_dt, maybeSource);

        if (rawPrices.isEmpty() || maybeBaseCurrency == null || maybeBaseCurrency.isBlank()) {
            return rawPrices;   // nothing to convert or no base requested
        }

        // 2) Convert to base currency
        final String baseCcy = maybeBaseCurrency.trim().toUpperCase(Locale.ROOT);

        // If all rows already in base, short-circuit
        boolean allBase = rawPrices.stream()
                .allMatch(r -> baseCcy.equalsIgnoreCase(r.currency()));
        if (allBase) return rawPrices;

        // 2) Collect all distinct source currencies in result set
        final Set<String> sourceCurrencies = rawPrices.stream()
                .map(PriceRowDTO::currency)
                .map(c -> c == null ? "" : c.trim().toUpperCase(Locale.ROOT))
                .filter(c -> !c.isBlank())
                .filter(c -> !c.equals(baseCcy))
                .collect(Collectors.toSet());

        if (sourceCurrencies.isEmpty()) return rawPrices;


        // 3) Build a per-day FX map from sourceCurrency -> (rate_date -> rateToBase)
        //    Using strategy: direct, inverse, else triangulate via USD.
        final Map<String, Map<LocalDate, BigDecimal>> fxToBaseByCcy = new HashMap<>();

        for (String sourceCurrency : sourceCurrencies) {
            if (sourceCurrency.equals(baseCcy)) continue;

            // Try direct/inverse first
            Map<LocalDate, BigDecimal> directOrInverse = buildDirectOrInverseRateMap(sourceCurrency, baseCcy, from_dt, to_dt);

            // If some dates are missing, fill gaps via USD triangulation
            if (!coversRange(directOrInverse, from_dt, to_dt)) {
                Map<LocalDate, BigDecimal> viaUSD = buildViaUsdRateMap(sourceCurrency, baseCcy, from_dt, to_dt);
                // merge: prefer directOrInverse where present; else viaUSD

                Map<LocalDate, BigDecimal> mergedRates = new HashMap<>(viaUSD);
                mergedRates.putAll(directOrInverse);
                directOrInverse = mergedRates;
            }

            fxToBaseByCcy.put(sourceCurrency, directOrInverse);
        }
        return rawPrices.stream()
                .map(price -> convertIfNeeded(price, baseCcy, fxToBaseByCcy))
                .collect(Collectors.toList());
    }

    // --- helpers ---

    /**
     * Convert a single price row to base currency if needed.
     *
     * @param row            input price row (native currency)
     * @param baseCcy        requested base currency (normalized upper-case)
     * @param fxToBaseByCcy  per-currency map of date→rate(src→base)
     * @return converted row if rate present for that date, otherwise original row
     */
    private PriceRowDTO convertIfNeeded(PriceRowDTO row,
                                        String baseCcy,
                                        Map<String, Map<LocalDate, BigDecimal>> fxToBaseByCcy) {
        final String srcCcy = safeUpper(row.currency());
        if (srcCcy.equals(baseCcy)) return row;

        final LocalDate d = row.priceTs().atZone(ZoneOffset.UTC).toLocalDate();
        final BigDecimal rate = Optional.ofNullable(fxToBaseByCcy.get(srcCcy))
                .map(m -> m.get(d))
                .orElse(null);

        if (rate == null) {
            // No rate for that day — return row as-is (you could also drop or flag it)
            return row;
        }

        // price_in_base = price_in_src * rate(src->base)
        final BigDecimal converted = row.price()
                .multiply(rate)
                .setScale(8, RoundingMode.HALF_UP);

        return new PriceRowDTO(
                row.priceTs(),
                converted,
                baseCcy,
                row.source()
        );
    }

    /**
     * Build a date→rate map for src→base using available direct or inverse pairs fetched in one round trip.
     *
     * <p>Rules:
     * <ul>
     *   <li>If both direct and inverse exist for a day, keep the direct</li>
     *   <li>Latest duplicate (same day) wins</li>
     * </ul>
     *
     * @param srcCcy  source currency code
     * @param baseCcy base currency code
     * @param from    inclusive start date
     * @param to      inclusive end date
     * @return map of date→rate(src→base)
     */
    private Map<LocalDate, BigDecimal> buildDirectOrInverseRateMap(String srcCcy,
                                                                   String baseCcy,
                                                                   LocalDate from,
                                                                   LocalDate to) {
        // One round trip pulls both A->B and B->A
        List<FxRateDTO> both = fxRateRepository.findFxRatesBothDirections(srcCcy, baseCcy, from, to);

        // Partition into direct and inverse
        Map<LocalDate, BigDecimal> direct = both.stream()
                .filter(r -> srcCcy.equalsIgnoreCase(r.fromCurrency())
                        && baseCcy.equalsIgnoreCase(r.toCurrency()))
                .collect(Collectors.toMap(
                        FxRateDTO::fxDate,
                        FxRateDTO::rate,
                        // same-day duplicates: keep the latest or any
                        (a, b) -> b,
                        HashMap::new
                ));

        Map<LocalDate, BigDecimal> inverse = both.stream()
                .filter(r -> baseCcy.equalsIgnoreCase(r.fromCurrency())
                        && srcCcy.equalsIgnoreCase(r.toCurrency()))
                .collect(Collectors.toMap(
                        FxRateDTO::fxDate,
                        r -> safeInverse(r.rate()),
                        (a, b) -> b,
                        HashMap::new
                ));

        // Merge (prefer direct if both exist for a day)
        Map<LocalDate, BigDecimal> merged = new HashMap<>(inverse);
        merged.putAll(direct);
        return merged;
    }

    /**
     * Triangulate missing days via USD: rate(src→base) = rate(src→USD) / rate(base→USD).
     */
    private Map<LocalDate, BigDecimal> buildViaUsdRateMap(String srcCcy,
                                                          String baseCcy,
                                                          LocalDate from,
                                                          LocalDate to) {
        // Fetch legs: src<->USD and base<->USD
        List<FxRateDTO> srcUsd = fxRateRepository.findFxRatesBothDirections(srcCcy, USD, from, to);
        List<FxRateDTO> baseUsd = fxRateRepository.findFxRatesBothDirections(baseCcy, USD, from, to);

        // Normalize legs to direction X->USD for src leg; B->USD for base leg
        Map<LocalDate, BigDecimal> srcToUsd = reduceToDirection(srcUsd, srcCcy, USD);
        Map<LocalDate, BigDecimal> baseToUsd = reduceToDirection(baseUsd, baseCcy, USD);

        // Build src->base = (src->USD) / (base->USD)
        Map<LocalDate, BigDecimal> out = new HashMap<>();
        LocalDate d = from;
        while (!d.isAfter(to)) {
            BigDecimal s = srcToUsd.get(d);
            BigDecimal b = baseToUsd.get(d);
            if (s != null && b != null && b.compareTo(BigDecimal.ZERO) != 0) {
                out.put(d, s.divide(b, 12, RoundingMode.HALF_UP));
            }
            d = d.plusDays(1);
        }
        return out;
    }

    /**
     * Reduce a list of FX legs to a single direction (fromCcy→toCcy).
     * Prefers direct; if only inverse exists, returns inverted values.
     */
    private Map<LocalDate, BigDecimal> reduceToDirection(List<FxRateDTO> legs,
                                                         String fromCcy,
                                                         String toCcy) {
        // Prefer direct(from->to); if only inverse is present, invert it
        Map<LocalDate, BigDecimal> direct = legs.stream()
                .filter(r -> fromCcy.equalsIgnoreCase(r.fromCurrency())
                        && toCcy.equalsIgnoreCase(r.toCurrency()))
                .collect(Collectors.toMap(FxRateDTO::fxDate, FxRateDTO::rate, (a, b) -> b));

        if (!direct.isEmpty()) return direct;

        return legs.stream()
                .filter(r -> toCcy.equalsIgnoreCase(r.fromCurrency())
                        && fromCcy.equalsIgnoreCase(r.toCurrency()))
                .collect(Collectors.toMap(FxRateDTO::fxDate, r -> safeInverse(r.rate()), (a, b) -> b));
    }

    /**
     * Quick coverage check: do we have at least one rate within [from, to]?
     */
    private static boolean coversRange(Map<LocalDate, BigDecimal> m, LocalDate from, LocalDate to) {
        if (m.isEmpty()) return false;
        // Quick check: have at least one in range and not just sparse single day
        return m.keySet().stream().anyMatch(d -> !d.isBefore(from) && !d.isAfter(to));
    }

    /** Safely invert x; returns null for null or zero. */
    private static BigDecimal safeInverse(BigDecimal x) {
        if (x == null || x.compareTo(BigDecimal.ZERO) == 0) return null;
        return BigDecimal.ONE.divide(x, 12, RoundingMode.HALF_UP);
    }

    /** Normalize a 3-letter currency code to upper-case, guarding nulls/whitespace. */
    private static String safeUpper(String c) {
        return c == null ? "" : c.trim().toUpperCase(Locale.ROOT);
    }
}
