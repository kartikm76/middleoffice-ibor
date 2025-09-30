package com.kmakker.ibor.ai;

import dev.langchain4j.agent.tool.Tool;
import org.springframework.stereotype.Component;
import com.kmakker.ibor.service.StructuredService;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Component
public class PositionTools {

    private final StructuredService structured;

    public PositionTools(StructuredService structured) {
        this.structured = structured;
    }

    @Tool("Get the aggregate position snapshot for an instrument and optional portfolio code filters. " +
          "Args: tickerOrId (string), portfolioCodes (array of strings). Returns a LIST of one JSON object with qty, side, MV, price.")
    public List<Map<String, Object>> getPosition(String tickerOrId, List<String> portfolioCodes) {
        Object result = structured.getPositionAggregate(tickerOrId, portfolioCodes);
        return normalizeToRows(result);
    }

    @Tool("Get forward cash projection for the next N days for the given portfolios. " +
          "Args: portfolioCodes (array of strings), days (int). Returns a LIST of rows (date, ccy, net).")
    public List<Map<String, Object>> getCashProjection(List<String> portfolioCodes, int days) {
        Object result = structured.cashProjection(portfolioCodes, days);
        return normalizeToRows(result);
    }

    /** Normalize any supported return type into List<Map<String,Object>> without unchecked casts. */
    private static List<Map<String, Object>> normalizeToRows(Object result) {
        List<Map<String, Object>> rows = new ArrayList<>();
        if (result == null) {
            return rows;
        }

        if (result instanceof Iterable<?> iterable) {
            for (Object o : iterable) {
                if (o instanceof Map<?, ?> raw) {
                    rows.add(copyAsStringKeyedMap(raw));
                } else {
                    rows.add(Map.of("value", String.valueOf(o)));
                }
            }
            return rows;
        }

        if (result instanceof Map<?, ?> raw) {
            rows.add(copyAsStringKeyedMap(raw));
            return rows;
        }

        // Fallback: wrap unknown single object as a one-field row
        rows.add(Map.of("value", String.valueOf(result)));
        return rows;
    }

    /** Create a new Map<String,Object> by coercing keys to String. */
    private static Map<String, Object> copyAsStringKeyedMap(Map<?, ?> raw) {
        Map<String, Object> out = new HashMap<>();
        for (Map.Entry<?, ?> e : raw.entrySet()) {
            out.put(String.valueOf(e.getKey()), e.getValue());
        }
        return out;
    }
}
