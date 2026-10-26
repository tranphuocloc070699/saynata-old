package com.example.app.common;

import java.util.Map;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * Turns exceptions into RFC 9457 Problem Details. Every response has a stable {@code code} and the
 * {@code requestId}, so a user report can be matched to the logs and to Sentry.
 */
@RestControllerAdvice
public class ApiExceptionHandler {

  private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);

  @ExceptionHandler(ApiException.class)
  ProblemDetail handleApi(ApiException e) {
    return problem(e.status(), e.code(), e.getMessage());
  }

  @ExceptionHandler(MethodArgumentNotValidException.class)
  ProblemDetail handleValidation(MethodArgumentNotValidException e) {
    Map<String, String> fields =
        e.getBindingResult().getFieldErrors().stream()
            .collect(
                Collectors.toMap(
                    f -> f.getField(),
                    f -> String.valueOf(f.getDefaultMessage()),
                    (first, second) -> first));
    ProblemDetail problem = problem(HttpStatus.BAD_REQUEST, "validation_failed", "Invalid request");
    problem.setProperty("fields", fields);
    return problem;
  }

  @ExceptionHandler(Exception.class)
  ProblemDetail handleUnexpected(Exception e) {
    // Logged with the stack trace (Sentry picks it up); the client sees no internals.
    log.error("Unexpected error", e);
    return problem(HttpStatus.INTERNAL_SERVER_ERROR, "internal_error", "Something went wrong");
  }

  private static ProblemDetail problem(HttpStatus status, String code, String detail) {
    ProblemDetail problem = ProblemDetail.forStatusAndDetail(status, detail);
    problem.setProperty("code", code);
    problem.setProperty("requestId", MDC.get(RequestIdFilter.MDC_KEY));
    return problem;
  }
}
