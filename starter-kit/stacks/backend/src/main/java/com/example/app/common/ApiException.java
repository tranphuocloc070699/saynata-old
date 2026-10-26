package com.example.app.common;

import org.springframework.http.HttpStatus;

/**
 * An error the client can act on. {@code code} is stable (clients switch on it); {@code message} is
 * for humans and may change.
 */
public class ApiException extends RuntimeException {

  private final HttpStatus status;
  private final String code;

  public ApiException(HttpStatus status, String code, String message) {
    super(message);
    this.status = status;
    this.code = code;
  }

  public static ApiException notFound(String code, String message) {
    return new ApiException(HttpStatus.NOT_FOUND, code, message);
  }

  public HttpStatus status() {
    return status;
  }

  public String code() {
    return code;
  }
}
