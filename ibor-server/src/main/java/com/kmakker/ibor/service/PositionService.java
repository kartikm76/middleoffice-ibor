package com.kmakker.ibor.service;

import com.kmakker.ibor.dto.PositionDTO;
import com.kmakker.ibor.jodi.JodiPositionsRepository;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;

@Service
public class PositionService {
    private static final int MAX_PAGE_SIZE = 500;
    private static final int DEFAULT_PAGE_SIZE = 100;

    private final JodiPositionsRepository positionsRepository;

    public PositionService(JodiPositionsRepository positionsRepository) {
        this.positionsRepository = positionsRepository;
    }

    public List<PositionDTO> getPositions(LocalDate asOf, String portfolioCode, Integer page, Integer size) {
        if (asOf == null) {
            throw new IllegalArgumentException("asOf must be provided (YYYY-MM-DD)");
        }
        if (portfolioCode == null || portfolioCode.isBlank()) {
            throw new IllegalArgumentException("portfolioCode must be provided");
        }
        int p = (page == null || page < 1) ? 1 : page;
        int s = (size == null || size <= 0) ? DEFAULT_PAGE_SIZE : Math.min(size, MAX_PAGE_SIZE);

        return positionsRepository.findPositions(asOf, portfolioCode, p, s);
    }
}
