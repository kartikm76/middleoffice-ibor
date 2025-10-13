package com.kmakker.ibor.integration;

import com.kmakker.ibor.IborApplication;
import com.kmakker.ibor.dto.PositionDTO;
import com.kmakker.ibor.jodi.JodiPositionsRepository;
import com.kmakker.ibor.support.PgWithProjectFiles;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.time.LocalDate;
import java.util.List;
import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(classes = IborApplication.class, webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
public class PositionIntegrationPostgresTest extends PgWithProjectFiles {
    @Autowired
    private JodiPositionsRepository jodiPositionsRepository;

    @Test
    void positions_work_against_real_postgres_schema_and_data() {
        List<PositionDTO> positions = jodiPositionsRepository.findPositions(
                    LocalDate.parse("2025-01-03"),
                    "P-ALPHA",
                    0,
                    10);
        // TODO: add assertions
        assertThat(positions).isNotEmpty();
    }
}
