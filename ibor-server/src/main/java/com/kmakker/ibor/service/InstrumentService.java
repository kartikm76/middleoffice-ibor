package com.kmakker.ibor.service;

import com.kmakker.ibor.jodi.JodiInstrumentRepository;
import com.kmakker.ibor.model.instrument.Instrument;
import org.springframework.stereotype.Service;
import java.time.LocalDate;
import java.util.Optional;

@Service
public class InstrumentService {
    private final JodiInstrumentRepository repo;

    public InstrumentService(JodiInstrumentRepository repo) {
        this.repo = repo;
    }

    /**
     * Returns the instrument as-of the given date, or Optional.empty() if not found.
     * Service layer does not throw; the controller maps Optional to HTTP response.
     */
    public Optional<Instrument> getInstrumentAsOf(String instrumentCode, LocalDate asOf) {
        return repo.findByCodeAsOf(instrumentCode, asOf);
    }
}
