package com.kmakker.ibor.repositories;

import com.kmakker.ibor.domain.CashEvent;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public interface CashEventRepository extends JpaRepository<CashEvent, Long> {

    @Query("""
              select ce.portfolio.id as portfolioId,
                     ce.ccy as ccy,
                     ce.valueDt as valueDt,
                     sum(ce.amount) as net
              from CashEvent ce
              where (:portfolioCodes is null or ce.portfolio.code in :portfolioCodes)
                and ce.valueDt <= :maxDate
              group by ce.portfolio.id, ce.ccy, ce.valueDt
              order by ce.valueDt
            """)
    List<CashProjectionRow> project(
            @Param("portfolioCodes") List<String> portfolioCodes,   // ALPHA, GM, etc.
            @Param("maxDate") LocalDate maxDate
    );

    interface CashProjectionRow {
        Integer getPortfolioId();   // int PK now
        String getCcy();
        LocalDate getValueDt();
        BigDecimal getNet();
    }
}