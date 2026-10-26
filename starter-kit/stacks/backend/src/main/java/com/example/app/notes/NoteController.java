package com.example.app.notes;

import com.example.app.notes.NoteDtos.CreateNoteRequest;
import com.example.app.notes.NoteDtos.NoteResponse;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** HTTP only: parse, validate, call the service. No logic here. */
@RestController
@RequestMapping("/api/v1/notes")
class NoteController {

  private final NoteService service;

  NoteController(NoteService service) {
    this.service = service;
  }

  @GetMapping
  List<NoteResponse> latest() {
    return service.latest();
  }

  @GetMapping("/{id}")
  NoteResponse get(@PathVariable long id) {
    return service.get(id);
  }

  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  NoteResponse create(@Valid @RequestBody CreateNoteRequest request) {
    return service.create(request);
  }
}
