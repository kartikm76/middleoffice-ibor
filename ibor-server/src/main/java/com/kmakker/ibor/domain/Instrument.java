package com.kmakker.ibor.domain;

import jakarta.persistence.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
@Entity
@Table(name = "instruments")
public class Instrument {
    // Getters and Setters
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;                 // int PK

    @Column(nullable = false, unique = true)
    private String ticker;

    @Column(nullable = false)
    private String assetClass;

    @Column(nullable = false)
    private String currency;

    private BigDecimal priceLast;

    private OffsetDateTime priceTime;
}