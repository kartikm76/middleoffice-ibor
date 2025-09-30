package com.kmakker.ibor.repositories.analytics;

import com.kmakker.ibor.dto.analytics.PortfolioReturnResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;

@Repository
public class PortfolioReturnRepository {
    private final JdbcTemplate jdbc;

    public PortfolioReturnRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<PortfolioReturnResponse.DailyReturn> findDailyReturns(String portfolioCode, String startDate, String endDate) {
        String sql = """
            SELECT r.return_as_of_date, r.twrr, r.total_mv_base
              FROM analytics.returns_portfolio_daily r
              JOIN portfolios p ON p.id = r.portfolio_id
             WHERE p.code = ?
               AND r.return_as_of_date BETWEEN ?::date AND ?::date
             ORDER BY r.return_as_of_date
            """;
        return jdbc.query(sql, (rs, rowNum) -> mapDaily(rs), portfolioCode, startDate, endDate);
    }

    private PortfolioReturnResponse.DailyReturn mapDaily(ResultSet rs) throws SQLException {
        return new PortfolioReturnResponse.DailyReturn(
                rs.getDate("return_as_of_date").toString(),
                rs.getDouble("twrr"),
                rs.getDouble("total_mv_base")
        );
    }
}