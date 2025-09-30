package com.kmakker.ibor.domain;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import lombok.ToString;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Getter
@Setter
@Entity
@Table(name = "trades")
@ToString
@JsonIgnoreProperties({"hibernateLazyInitializer","handler"})
public class Trade {

    @Id
    @Column(name = "trade_id")
    private String tradeId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "portfolio_id", nullable = false)
    @ToString.Exclude
    private Portfolio portfolio;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "instrument_id", nullable = false)
    @ToString.Exclude
    private Instrument instrument;

    @Column(nullable = false)
    private String side; // "BUY" / "SELL" (or use an enum)

    @Column(nullable = false, precision = 20, scale = 6)
    private BigDecimal qty;

    @Column(nullable = false, precision = 18, scale = 6)
    private BigDecimal price;

    @Column(name = "trade_dt", nullable = false)
    private OffsetDateTime tradeDt;

    @Column(name = "settle_dt", nullable = false)
    private OffsetDateTime settleDt;

    @Column(precision = 18, scale = 6)
    private BigDecimal fees = BigDecimal.ZERO;
}