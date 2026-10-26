package com.example.app.notes;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;

/** What the API reads and writes. Entities never leave the service. */
final class NoteDtos {

  private NoteDtos() {}

  record CreateNoteRequest(
      @NotBlank @Size(max = 200) String title, @Size(max = 10_000) String body) {}

  record NoteResponse(long id, String title, String body, Instant createdAt) {

    static NoteResponse from(Note note) {
      return new NoteResponse(note.getId(), note.getTitle(), note.getBody(), note.getCreatedAt());
    }
  }
}
