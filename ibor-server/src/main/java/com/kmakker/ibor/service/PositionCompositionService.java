package com.kmakker.ibor.service;

import com.kmakker.ibor.dto.PositionSummaryDTO;
import com.kmakker.ibor.jodi.JodiPositionCompositionRepository;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;

@Service
public class PositionCompositionService {
    private static final int DEFAULT_PAGE = 1;
    private static final int DEFAULT_SIZE = 50;
    private static final int MAX_PAGE_SIZE = 500;

    private final JodiPositionCompositionRepository positionCompositionRepository;

    public PositionCompositionService(JodiPositionCompositionRepository positionCompositionRepository) {
        this.positionCompositionRepository = positionCompositionRepository;
    }

    public List<PositionSummaryDTO> getComposition(LocalDate asOf, String portfolioCode, Integer page, Integer size) {
        if (asOf == null) throw new IllegalArgumentException("asOf is required");
        if (portfolioCode == null) throw new IllegalArgumentException("portfolioCode is required");
        int p = (page == null || page < DEFAULT_PAGE) ? DEFAULT_PAGE : page;
        int s = (size == null || size <= 0) ? DEFAULT_SIZE : Math.min(size, MAX_PAGE_SIZE);
        return positionCompositionRepository.findComposition(asOf, portfolioCode, p, s);
    }
}
