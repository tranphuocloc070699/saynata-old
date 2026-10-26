package com.example.app.notes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

/** A note. The table is created by Flyway (V1), never by Hibernate. */
@Entity
@Table(name = "notes")
public class Note {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(nullable = false)
  private String title;

  private String body;

  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt;

  protected Note() {} // for JPA

  public Note(String title, String body) {
    this.title = title;
    this.body = body;
    // Set here, not only by the DB default, so the saved object has it without a re-read.
    // Postgres keeps microseconds; Java has nanoseconds. Truncate so values read back are equal.
    this.createdAt = Instant.now().truncatedTo(ChronoUnit.MICROS);
  }

  public Long getId() {
    return id;
  }

  public String getTitle() {
    return title;
  }

  public String getBody() {
    return body;
  }

  public Instant getCreatedAt() {
    return createdAt;
  }
}
