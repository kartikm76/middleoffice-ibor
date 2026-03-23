package com.kmakker.ibor.repositories.analytics;

import com.kmakker.ibor.dto.analytics.BenchmarkSegmentResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;

@Repository
public class BenchmarkSegmentRepository {

    private final JdbcTemplate jdbc;

    public BenchmarkSegmentRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<BenchmarkSegmentResponse.SegmentRow> findSegments(String benchmarkCode, String startDate, String endDate) {
        String sql = """
            SELECT bsd.benchmark_as_of_date,
                   bsd.segment_key,
                   bsd.benchmark_weight,
                   bsd.benchmark_return_segment
              FROM analytics.benchmark_segments_daily bsd
              JOIN analytics.benchmarks bm ON bm.id = bsd.benchmark_id
             WHERE bm.code = ?
               AND bsd.benchmark_as_of_date BETWEEN ?::date AND ?::date
             ORDER BY bsd.benchmark_as_of_date, bsd.segment_key
            """;
        return jdbc.query(sql, (rs, rowNum) -> map(rs), benchmarkCode, startDate, endDate);
    }

    private BenchmarkSegmentResponse.SegmentRow map(ResultSet rs) throws SQLException {
        return new BenchmarkSegmentResponse.SegmentRow(
                rs.getDate("benchmark_as_of_date").toString(),
                rs.getString("segment_key"),
                rs.getDouble("benchmark_weight"),
                rs.getDouble("benchmark_return_segment")
        );
    }
}