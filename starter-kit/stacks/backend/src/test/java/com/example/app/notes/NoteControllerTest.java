package com.example.app.notes;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.example.app.common.ApiException;
import com.example.app.notes.NoteDtos.NoteResponse;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

/** Fast web-layer test: no database, the service is a mock. */
@WebMvcTest(NoteController.class)
class NoteControllerTest {

  @Autowired MockMvc mvc;
  @MockitoBean NoteService service;

  @Test
  void createReturns201WithTheNote() throws Exception {
    when(service.create(any()))
        .thenReturn(new NoteResponse(1, "Hello", null, Instant.parse("2026-01-01T00:00:00Z")));

    mvc.perform(
            post("/api/v1/notes")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"title\":\"Hello\"}"))
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.id").value(1))
        .andExpect(header().exists("X-Request-Id"));
  }

  @Test
  void blankTitleIsAValidationProblem() throws Exception {
    mvc.perform(
            post("/api/v1/notes")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"title\":\"  \"}"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.code").value("validation_failed"))
        .andExpect(jsonPath("$.fields.title").exists());
  }

  @Test
  void missingNoteIsA404WithAStableCode() throws Exception {
    when(service.get(42)).thenThrow(ApiException.notFound("note_not_found", "No note with id 42"));

    mvc.perform(get("/api/v1/notes/42").header("X-Request-Id", "test-request-1"))
        .andExpect(status().isNotFound())
        .andExpect(jsonPath("$.code").value("note_not_found"))
        .andExpect(jsonPath("$.requestId").value("test-request-1"));
  }
}
