package com.example.app.notes;

import com.example.app.common.ApiException;
import com.example.app.notes.NoteDtos.CreateNoteRequest;
import com.example.app.notes.NoteDtos.NoteResponse;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Limit;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class NoteService {

  static final int MAX_LIST = 100;
  private static final Logger log = LoggerFactory.getLogger(NoteService.class);

  private final NoteRepository notes;

  NoteService(NoteRepository notes) {
    this.notes = notes;
  }

  @Transactional(readOnly = true)
  public List<NoteResponse> latest() {
    return notes.findAllByOrderByIdDesc(Limit.of(MAX_LIST)).stream()
        .map(NoteResponse::from)
        .toList();
  }

  @Transactional(readOnly = true)
  public NoteResponse get(long id) {
    return notes
        .findById(id)
        .map(NoteResponse::from)
        .orElseThrow(() -> ApiException.notFound("note_not_found", "No note with id " + id));
  }

  @Transactional
  public NoteResponse create(CreateNoteRequest request) {
    Note saved = notes.saveAndFlush(new Note(request.title().strip(), request.body()));
    // Log ids and sizes, never the user's text.
    log.info("note_created id={} title_length={}", saved.getId(), saved.getTitle().length());
    return NoteResponse.from(saved);
  }
}
