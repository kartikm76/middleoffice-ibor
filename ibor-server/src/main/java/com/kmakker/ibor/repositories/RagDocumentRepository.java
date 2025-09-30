package com.kmakker.ibor.repositories;

import com.kmakker.ibor.domain.RagDocument;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface RagDocumentRepository extends JpaRepository<RagDocument, UUID> {}