package com.zairo.factory.storage;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.charset.StandardCharsets;
import java.util.Optional;
import org.junit.jupiter.api.Test;

/** Pure byte-sniffing logic — no Spring/MinIO/Docker needed, unlike StorageApiTests. */
class DetectedImageTypeTest {

    private static final byte[] JPEG_BYTES = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0, 0, 0, 'J', 'F',
            'I', 'F'};
    private static final byte[] PNG_BYTES = {(byte) 0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n', 0, 0};
    private static final byte[] WEBP_BYTES = {'R', 'I', 'F', 'F', 0, 0, 0, 0, 'W', 'E', 'B', 'P'};

    @Test
    void detectsAValidJpeg() {
        assertEquals(Optional.of(DetectedImageType.JPEG), DetectedImageType.detect(JPEG_BYTES));
    }

    @Test
    void detectsAValidPng() {
        assertEquals(Optional.of(DetectedImageType.PNG), DetectedImageType.detect(PNG_BYTES));
    }

    @Test
    void detectsAValidWebp() {
        assertEquals(Optional.of(DetectedImageType.WEBP), DetectedImageType.detect(WEBP_BYTES));
    }

    @Test
    void rejectsHtml() {
        byte[] html = "<html><body><script>alert(1)</script></body></html>".getBytes(StandardCharsets.UTF_8);
        assertEquals(Optional.empty(), DetectedImageType.detect(html));
    }

    @Test
    void rejectsSvg() {
        byte[] svg = "<?xml version=\"1.0\"?><svg><script>alert(1)</script></svg>".getBytes(StandardCharsets.UTF_8);
        assertEquals(Optional.empty(), DetectedImageType.detect(svg));
    }

    @Test
    void rejectsAnImageExtensionDisguisingNonImageBytes() {
        // The point being tested: detect() only ever looks at the bytes — there's no filename/extension
        // parameter to even mislead it with.
        byte[] html = "<html>not really a jpeg</html>".getBytes(StandardCharsets.UTF_8);
        assertEquals(Optional.empty(), DetectedImageType.detect(html));
    }

    @Test
    void rejectsAnEmptyOrTooShortFile() {
        assertEquals(Optional.empty(), DetectedImageType.detect(new byte[0]));
        assertEquals(Optional.empty(), DetectedImageType.detect(new byte[] {(byte) 0xFF, (byte) 0xD8}));
    }

    @Test
    void rejectsAnArbitraryExecutable() {
        byte[] exe = {'M', 'Z', (byte) 0x90, 0, 3, 0, 0, 0};
        assertEquals(Optional.empty(), DetectedImageType.detect(exe));
    }

    @Test
    void resolvesContentTypeOnlyForAllowlistedValues() {
        assertTrue(DetectedImageType.forContentType("image/jpeg").isPresent());
        assertTrue(DetectedImageType.forContentType("image/png").isPresent());
        assertTrue(DetectedImageType.forContentType("image/webp").isPresent());
        assertEquals(Optional.empty(), DetectedImageType.forContentType("text/html"));
        assertEquals(Optional.empty(), DetectedImageType.forContentType("image/svg+xml"));
        assertEquals(Optional.empty(), DetectedImageType.forContentType(null));
    }
}
