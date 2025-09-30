package com.kmakker.ibor.repositories;

import com.kmakker.ibor.domain.Portfolio;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface PortfolioRepository extends JpaRepository<Portfolio,Integer> {
    Optional<Portfolio> findByCode(String code);

    @Query("select p.id from Portfolio p where p.code = :code")
    Optional<Integer> findIdByCode(@Param("code") String code);
}
