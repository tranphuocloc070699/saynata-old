package com.englishtranslation.backend.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.Base64;
import org.junit.jupiter.api.Test;

class AppleTokenCipherTest {

    private final AppleTokenCipher cipher = new AppleTokenCipher(AppleTokenTestKeys.ENCRYPTION_KEY);

    @Test
    void encryptsAndDecryptsWithARandomIvEachTime() {
        String a = cipher.encrypt("r-123");
        String b = cipher.encrypt("r-123");

        assertThat(a).isNotEqualTo(b).doesNotContain("r-123");
        assertThat(cipher.decrypt(a)).isEqualTo("r-123");
        assertThat(cipher.decrypt(b)).isEqualTo("r-123");
    }

    @Test
    void aChangedTextOrAnotherKeyCannotDecrypt() {
        String sealed = cipher.encrypt("r-123");
        byte[] bytes = Base64.getDecoder().decode(sealed);
        bytes[bytes.length - 1] ^= 1;

        assertThatThrownBy(() -> cipher.decrypt(Base64.getEncoder().encodeToString(bytes)))
                .isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> new AppleTokenCipher(AppleTokenTestKeys.newEncryptionKey()).decrypt(sealed))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void aKeyThatIsNot32BytesIsRefused() {
        assertThatThrownBy(() -> new AppleTokenCipher(Base64.getEncoder().encodeToString(new byte[16])))
                .hasMessageContaining("32 bytes");
        assertThatThrownBy(() -> new AppleTokenCipher("not base64 !!")).hasMessageContaining("base64");
    }
}
