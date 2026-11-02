package com.englishtranslation.backend.term;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * TASK-119.1: one named thing in a word reply. {@code field} says what it is ("JavaScript runtime"),
 * {@code simpleDefinition} is one easy sentence (null until written, TASK-119.4). Both links come from Wikidata,
 * never from an LLM. Null fields are left out of the JSON.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record Term(String name, String field, String simpleDefinition, String officialUrl, String wikipediaUrl) {
}
