package com.example.app.notes;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.example.app.common.ApiException;
import com.example.app.notes.NoteDtos.CreateNoteRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

/**
 * Full flow against a real Postgres in Docker (same major version as prod), with the real Flyway
 * migrations. Skipped when Docker is not running.
 */
@SpringBootTest
@Testcontainers(disabledWithoutDocker = true)
class NoteFlowIntegrationTest {

  @Container @ServiceConnection
  static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18-alpine");

  @Autowired NoteService service;

  @Test
  void createdNoteCanBeReadBackAndIsFirstInTheList() {
    var created = service.create(new CreateNoteRequest("  First note ", "body"));

    assertThat(created.title()).isEqualTo("First note");
    assertThat(created.createdAt()).isNotNull();
    assertThat(service.get(created.id())).isEqualTo(created);
    assertThat(service.latest()).first().isEqualTo(created);
  }

  @Test
  void unknownIdThrowsNotFound() {
    assertThatThrownBy(() -> service.get(999_999))
        .isInstanceOf(ApiException.class)
        .hasFieldOrPropertyWithValue("code", "note_not_found");
  }
}
