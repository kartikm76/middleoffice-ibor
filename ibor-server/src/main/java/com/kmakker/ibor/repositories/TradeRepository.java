package com.kmakker.ibor.repositories;

import com.kmakker.ibor.domain.Trade;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.util.List;

public interface TradeRepository extends JpaRepository<Trade, String> {

    @Query("""
              select coalesce(sum(case when t.side='BUY' then t.qty else -t.qty end), 0)
              from Trade t
              where t.instrument.id = :instrumentId
                and (:portfolioIds is null or t.portfolio.id in :portfolioIds)
            """)
    BigDecimal netQty(@Param("instrumentId") Integer instrumentId,
                      @Param("portfolioIds") List<Integer> portfolioIds);

    @Query("""
              select t.portfolio.id as portfolioId,
                     coalesce(sum(case when t.side='BUY' then t.qty else -t.qty end), 0) as qty
              from Trade t
              where t.instrument.id = :instrumentId
              group by t.portfolio.id
              order by t.portfolio.id
            """)
    List<ByPortfolioRow> byPortfolio(@Param("instrumentId") Integer instrumentId);

    interface ByPortfolioRow {
        Integer getPortfolioId();

        java.math.BigDecimal getQty();
    }
}


