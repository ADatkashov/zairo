package com.zairo.factory.storage;

import java.util.Optional;

/**
 * The file types this module actually needs to serve safely: cover photos
 * and portfolio images (see {@code ProviderDtos}/{@code MasterDtos}), the
 * only two things anything currently uploads through this endpoint.
 *
 * Detection reads the file's own leading bytes ("magic numbers"), never the
 * client-supplied filename extension or {@code Content-Type} header — both
 * are attacker-controlled, and trusting either is exactly how an HTML/SVG
 * file previously got served back with a browser-executable Content-Type
 * (stored XSS). Anything that doesn't match one of these signatures is
 * rejected outright, so this also rejects HTML/SVG/scripts and any image
 * format outside this short list, by construction rather than a denylist.
 */
enum DetectedImageType {

    JPEG("image/jpeg", ".jpg") {
        @Override
        boolean matchesHeader(byte[] header) {
            return header.length >= 3 && unsigned(header[0]) == 0xFF && unsigned(header[1]) == 0xD8
                    && unsigned(header[2]) == 0xFF;
        }
    },
    PNG("image/png", ".png") {
        @Override
        boolean matchesHeader(byte[] header) {
            byte[] signature = {(byte) 0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n'};
            return startsWith(header, signature);
        }
    },
    WEBP("image/webp", ".webp") {
        @Override
        boolean matchesHeader(byte[] header) {
            // RIFF <4-byte chunk size, ignored> WEBP
            return header.length >= 12 && startsWith(header, new byte[] {'R', 'I', 'F', 'F'}) && header[8] == 'W'
                    && header[9] == 'E' && header[10] == 'B' && header[11] == 'P';
        }
    };

    final String contentType;
    final String extension;

    DetectedImageType(String contentType, String extension) {
        this.contentType = contentType;
        this.extension = extension;
    }

    abstract boolean matchesHeader(byte[] header);

    /** Inspects the file's actual bytes; empty if none of the allowed image formats match. */
    static Optional<DetectedImageType> detect(byte[] content) {
        for (DetectedImageType type : values()) {
            if (type.matchesHeader(content)) {
                return Optional.of(type);
            }
        }
        return Optional.empty();
    }

    /** Used on download to re-validate previously stored metadata against the same allowlist — see
     * StorageService.download's doc comment for why that matters even though upload already validated. */
    static Optional<DetectedImageType> forContentType(String contentType) {
        if (contentType == null) {
            return Optional.empty();
        }
        for (DetectedImageType type : values()) {
            if (type.contentType.equals(contentType)) {
                return Optional.of(type);
            }
        }
        return Optional.empty();
    }

    private static int unsigned(byte b) {
        return b & 0xFF;
    }

    private static boolean startsWith(byte[] data, byte[] prefix) {
        if (data.length < prefix.length) {
            return false;
        }
        for (int i = 0; i < prefix.length; i++) {
            if (data[i] != prefix[i]) {
                return false;
            }
        }
        return true;
    }
}
