package com.kmakker.ibor.support;

import org.junit.jupiter.api.TestInstance;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;
import org.testcontainers.utility.MountableFile;

import java.io.BufferedReader;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;
import java.util.stream.Stream;

@Testcontainers
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
public abstract class PgWithProjectFiles {

    // --- Container definition ---
    protected static final PostgreSQLContainer<?> PG =
            new PostgreSQLContainer<>(DockerImageName.parse("pgvector/pgvector:pg16"))
                    .withDatabaseName("ibor")
                    .withUsername("ibor")
                    .withPassword("ibor");

    private static volatile boolean INITIALISED = false;

    // Start the container BEFORE Spring reads DynamicPropertySource
    static {
        PG.start();
        try {
            initOnce();
        } catch (Exception e) {
            throw new ExceptionInInitializerError(e);
        }
    }

    // --- Resolve host dirs (works from module dir or project root) ---
    private static Path resolveFirstExisting(List<Path> candidates) {
        for (Path p : candidates) {
            if (Files.isDirectory(p)) return p.toAbsolutePath().normalize();
        }
        throw new IllegalStateException("None of these directories exist: " + candidates);
    }

    private static Path resolveInitDir() {
        return resolveFirstExisting(List.of(
                Paths.get("docker/db/init"),
                Paths.get("../docker/db/init"),
                Paths.get("../../docker/db/init")
        ));
    }

    private static Path resolveDataDir() {
        return resolveFirstExisting(List.of(
                Paths.get("docker/db/data"),
                Paths.get("../docker/db/data"),
                Paths.get("../../docker/db/data")
        ));
    }

    private static synchronized void initOnce() throws Exception {
        if (INITIALISED) return;

        Path initDir = resolveInitDir();
        Path dataDir = resolveDataDir();

        log("INIT_DIR=" + initDir);
        log("DATA_DIR=" + dataDir);

        // Ensure target dirs exist in the container
        execInContainerOk("bash", "-lc", "mkdir -p /init /data");

        // Copy files into container
        copyDirectoryToContainer(initDir, "/init");
        copyDirectoryToContainer(dataDir, "/data");

        // List for sanity
        execInContainerOk("bash", "-lc", "echo '--- /init'; ls -la /init || true");
        execInContainerOk("bash", "-lc", "echo '--- /data'; ls -la /data || true");

        // Run schema in order (keep your exact order)
        execSQL("/init/01_main_schema.sql");
        execSQL("/init/02_staging_schema.sql");
        execSQL("/init/03_audit_trigger.sql");
        execSQL("/init/04_loaders.sql");
        execSQL("/init/05_helpers.sql");

        // Load every stg_*.csv using the header as the column list
        loadAllStagingCsvs(dataDir);

        // Run curated loaders (if defined)
        execPsql("SELECT ibor.run_all_loaders();");

        INITIALISED = true;
        log("Container initialisation complete.");
    }

    // --- Spring datasource & dialect from the container (now that it's started) ---
    @DynamicPropertySource
    static void springProps(DynamicPropertyRegistry r) {
        r.add("spring.datasource.url", PG::getJdbcUrl);
        r.add("spring.datasource.username", PG::getUsername);
        r.add("spring.datasource.password", PG::getPassword);
        r.add("spring.jooq.sql-dialect", () -> "POSTGRES");
        r.add("spring.jpa.database-platform", () -> "org.hibernate.dialect.PostgreSQLDialect");
        r.add("spring.jpa.hibernate.ddl-auto", () -> "none");
    }

    // ---------- CSV LOADING (header → column list) ----------

    private static void loadAllStagingCsvs(Path dataDir) throws IOException, InterruptedException {
        List<Path> csvs = new ArrayList<>();
        try (Stream<Path> s = Files.walk(dataDir)) {
            csvs = s.filter(Files::isRegularFile)
                    .filter(p -> {
                        String n = p.getFileName().toString().toLowerCase();
                        return n.endsWith(".csv") && n.startsWith("stg_");
                    })
                    .sorted((a, b) -> a.getFileName().toString().compareToIgnoreCase(b.getFileName().toString()))
                    .collect(Collectors.toList());
        }

        for (Path hostCsv : csvs) {
            String fileName = hostCsv.getFileName().toString();        // e.g. stg_currency.csv
            String base = fileName.substring(0, fileName.length() - 4); // e.g. stg_currency
            String table = "stg." + base.substring("stg_".length());    // e.g. stg.currency

            // Read the header row from the HOST file
            String header = readFirstLine(hostCsv);
            if (header == null || header.isBlank()) {
                throw new IllegalStateException("Empty CSV (no header): " + hostCsv.toAbsolutePath());
            }
            // Build quoted identifier list: "col1", "col 2", ...
            String columnList = buildQuotedIdentifierListFromCsvHeader(header);

            String containerCsv = "/data/" + fileName;
            String psql = "\\copy " + table + " (" + columnList + ") FROM '" + containerCsv + "' CSV HEADER NULL ''";
            log("CSV LOAD -> " + psql);
            execPsql(psql);
        }
    }

    private static String readFirstLine(Path file) throws IOException {
        try (BufferedReader br = Files.newBufferedReader(file, StandardCharsets.UTF_8)) {
            String line = br.readLine();
            // Strip potential UTF-8 BOM
            if (line != null && !line.isEmpty() && line.charAt(0) == '\uFEFF') {
                line = line.substring(1);
            }
            return line;
        }
    }

    private static String buildQuotedIdentifierListFromCsvHeader(String header) {
        return Stream.of(header.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .map(PgWithProjectFiles::quoteIdent)
                .collect(Collectors.joining(", "));
    }

    private static String quoteIdent(String raw) {
        // Double-quote and escape internal quotes per SQL rules
        String cleaned = Objects.requireNonNull(raw).replace("\"", "\"\"");
        return "\"" + cleaned + "\"";
    }

    // ---------- Helpers ----------

    private static void execSQL(String fileInContainer) throws IOException, InterruptedException {
        String cmd = "psql -v ON_ERROR_STOP=1 -U " + PG.getUsername()
                + " -d " + PG.getDatabaseName()
                + " -f " + fileInContainer;
        var res = PG.execInContainer("bash", "-lc", cmd);
        if (res.getExitCode() != 0) {
            throw new IllegalStateException("Failed SQL: " + fileInContainer
                    + "\nstdout:\n" + res.getStdout()
                    + "\nstderr:\n" + res.getStderr());
        }
    }

    private static void execPsql(String psqlCommand) throws IOException, InterruptedException {
        // Use -c for inline commands (\copy etc.), escape quotes
        String escaped = psqlCommand.replace("\"", "\\\"");
        String cmd = "psql -v ON_ERROR_STOP=1 -U " + PG.getUsername()
                + " -d " + PG.getDatabaseName()
                + " -c \"" + escaped + "\"";
        var res = PG.execInContainer("bash", "-lc", cmd);
        if (res.getExitCode() != 0) {
            throw new IllegalStateException("Failed psql command: " + psqlCommand
                    + "\nstdout:\n" + res.getStdout()
                    + "\nstderr:\n" + res.getStderr());
        }
    }

    private static void copyDirectoryToContainer(Path hostDir, String containerDir) throws IOException {
        if (!Files.isDirectory(hostDir)) {
            throw new IllegalStateException("Host directory does not exist: " + hostDir);
        }
        try (Stream<Path> files = Files.walk(hostDir)) {
            files.filter(Files::isRegularFile).forEach(hostFile -> {
                String rel = hostDir.relativize(hostFile).toString().replace('\\', '/');
                String dest = containerDir + "/" + rel;
                try {
                    // ensure parent dirs
                    int lastSlash = dest.lastIndexOf('/');
                    if (lastSlash > 0) {
                        String parent = dest.substring(0, lastSlash);
                        execInContainerOk("bash", "-lc", "mkdir -p " + parent);
                    }
                    PG.copyFileToContainer(MountableFile.forHostPath(hostFile), dest);
                } catch (Exception e) {
                    throw new RuntimeException("Failed to copy " + hostFile + " -> " + dest, e);
                }
            });
        }
    }

    private static void execInContainerOk(String... cmd) {
        try {
            var res = PG.execInContainer(cmd);
            if (res.getExitCode() != 0) {
                throw new IllegalStateException("Container cmd failed: "
                        + String.join(" ", cmd) + "\nstdout:\n" + res.getStdout()
                        + "\nstderr:\n" + res.getStderr());
            }
        } catch (IOException | InterruptedException e) {
            throw new RuntimeException(e);
        }
    }

    private static void log(String s) {
        System.out.println("[PgWithProjectFiles] " + s);
    }
}