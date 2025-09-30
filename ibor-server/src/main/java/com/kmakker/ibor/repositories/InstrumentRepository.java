package com.kmakker.ibor.repositories;

import com.kmakker.ibor.domain.Instrument;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface InstrumentRepository extends JpaRepository<Instrument,Integer> {
    Optional<Instrument> findById(Integer id);
    Optional<Instrument> findByTicker(String ticker);

    @Query("select i.id from Instrument i where i.ticker = :ticker")
    Optional<Integer> findIdByTicker(@Param("ticker") String ticker);
}