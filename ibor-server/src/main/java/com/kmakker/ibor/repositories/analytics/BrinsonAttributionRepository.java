package com.kmakker.ibor.repositories.analytics;

import com.kmakker.ibor.dto.analytics.BrinsonAttributionDailyResponse;
import com.kmakker.ibor.dto.analytics.BrinsonAttributionPeriodResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;

@Repository
public class BrinsonAttributionRepository {

    private final JdbcTemplate jdbc;

    public BrinsonAttributionRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<BrinsonAttributionDailyResponse.DailyRow> findDaily(String portfolioCode, String benchmarkCode, String startDate, String endDate) {
        String sql = """
            SELECT a.attribution_as_of_date,
                   a.segment_key,
                   a.alloc_contrib,
                   a.sel_contrib,
                   a.int_contrib,
                   a.total_contrib
              FROM analytics.attribution_brinson_daily a
              JOIN portfolios p ON p.id = a.portfolio_id
              JOIN analytics.benchmarks bm ON bm.id = a.benchmark_id
             WHERE p.code = ?
               AND bm.code = ?
               AND a.attribution_as_of_date BETWEEN ?::date AND ?::date
             ORDER BY a.attribution_as_of_date, a.segment_key
            """;
        return jdbc.query(sql, (rs, rowNum) -> mapDaily(rs), portfolioCode, benchmarkCode, startDate, endDate);
    }

    public List<BrinsonAttributionPeriodResponse.SegmentRow> findPeriod(String portfolioCode, String benchmarkCode, String startDate, String endDate) {
        String sql = """
            SELECT a.segment_key,
                   SUM(a.alloc_contrib) AS alloc_contrib,
                   SUM(a.sel_contrib)   AS sel_contrib,
                   SUM(a.int_contrib)   AS int_contrib,
                   SUM(a.total_contrib) AS total_contrib
              FROM analytics.attribution_brinson_daily a
              JOIN portfolios p ON p.id = a.portfolio_id
              JOIN analytics.benchmarks bm ON bm.id = a.benchmark_id
             WHERE p.code = ?
               AND bm.code = ?
               AND a.attribution_as_of_date BETWEEN ?::date AND ?::date
             GROUP BY a.segment_key
             ORDER BY a.segment_key
            """;
        return jdbc.query(sql, (rs, rowNum) -> mapPeriod(rs), portfolioCode, benchmarkCode, startDate, endDate);
    }

    private BrinsonAttributionDailyResponse.DailyRow mapDaily(ResultSet rs) throws SQLException {
        return new BrinsonAttributionDailyResponse.DailyRow(
                rs.getDate("attribution_as_of_date").toString(),
                rs.getString("segment_key"),
                rs.getDouble("alloc_contrib"),
                rs.getDouble("sel_contrib"),
                rs.getDouble("int_contrib"),
                rs.getDouble("total_contrib")
        );
    }

    private BrinsonAttributionPeriodResponse.SegmentRow mapPeriod(ResultSet rs) throws SQLException {
        return new BrinsonAttributionPeriodResponse.SegmentRow(
                rs.getString("segment_key"),
                rs.getDouble("alloc_contrib"),
                rs.getDouble("sel_contrib"),
                rs.getDouble("int_contrib"),
                rs.getDouble("total_contrib")
        );
    }
}