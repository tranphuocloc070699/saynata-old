package com.example.app.notes;

import java.util.List;
import org.springframework.data.domain.Limit;
import org.springframework.data.jpa.repository.JpaRepository;

interface NoteRepository extends JpaRepository<Note, Long> {

  List<Note> findAllByOrderByIdDesc(Limit limit);
}
