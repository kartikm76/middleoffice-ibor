package com.kmakker.ibor.repositories.analytics;

import com.kmakker.ibor.dto.SecurityReturnResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;

@Repository
public class SecurityReturnRepository {

    private final JdbcTemplate jdbc;

    public SecurityReturnRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<SecurityReturnResponse.SecurityRow> findbyPortfolioAndDate(String portfolioCode, String asOfDate) {
        String sql = """
                        SELECT i.ticker,
                               h.segment_key,
                               h.weight,
                               rsd.return
                          FROM analytics.holdings_daily h
                          JOIN analytics.returns_security_daily rsd
                            ON rsd.portfolio_id = h.portfolio_id
                           AND rsd.instrument_id = h.instrument_id
                           AND rsd.return_as_of_date = h.holding_as_of_date
                          JOIN instruments i ON i.id = h.instrument_id
                          JOIN portfolios p ON p.id = h.portfolio_id
                         WHERE p.code = ?
                           AND h.holding_as_of_date = ?::date
                         ORDER BY i.ticker
                """;
        return jdbc.query(sql, (rs, rowNum) -> map(rs), portfolioCode, asOfDate);
    }
    private SecurityReturnResponse.SecurityRow map(ResultSet rs) throws SQLException {
        return new SecurityReturnResponse.SecurityRow(
                rs.getString("ticker"),
                rs.getString("segment_key"),
                rs.getDouble("weight"),
                rs.getDouble("return")
        );
    }
}
