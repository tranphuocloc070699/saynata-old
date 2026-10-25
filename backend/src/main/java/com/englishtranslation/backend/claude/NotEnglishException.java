package com.englishtranslation.backend.claude;

/**
 * The text cannot be explained: it is gibberish or code ({@link #notAWord()}) or only a person's name
 * ({@link #aName()}). Other languages are explained, so this is no longer about "not English". It becomes HTTP 422
 * with a {@code code} the clients can read, and nothing is cached.
 */
public class NotEnglishException extends RuntimeException {

    public static final String NOT_A_WORD_CODE = "not_a_word";
    public static final String A_NAME_CODE = "a_name";
    public static final String NOT_A_WORD_MESSAGE = "This does not look like a word or a sentence. Check the spelling.";
    public static final String A_NAME_MESSAGE = "This looks like a person's name, so there is nothing to explain.";

    private final String code;

    private NotEnglishException(String code, String message) {
        super(message);
        this.code = code;
    }

    /** Gibberish, random letters or program code. */
    public static NotEnglishException notAWord() {
        return new NotEnglishException(NOT_A_WORD_CODE, NOT_A_WORD_MESSAGE);
    }

    /** The whole text is only the name of a person. */
    public static NotEnglishException aName() {
        return new NotEnglishException(A_NAME_CODE, A_NAME_MESSAGE);
    }

    public String code() {
        return code;
    }
}
