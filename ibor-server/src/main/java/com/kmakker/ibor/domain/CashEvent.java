package com.kmakker.ibor.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter
@Setter
@Entity
@Table(name = "cash_events")
public class CashEvent {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name="portfolio_id")
    private Portfolio portfolio;

    @Column(nullable=false)
    private String ccy;

    @Column(nullable=false)
    private LocalDate valueDt;

    @Column(nullable=false)
    private BigDecimal amount;
    private String description;
}
