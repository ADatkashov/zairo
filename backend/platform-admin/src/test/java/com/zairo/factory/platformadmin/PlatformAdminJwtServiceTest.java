package com.zairo.factory.platformadmin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class PlatformAdminJwtServiceTest {

    @Test
    void issuedTokenValidatesBackToTheSameAdminIdAndRole() {
        PlatformAdminJwtService jwtService = new PlatformAdminJwtService("a-test-secret-that-is-long-enough-1234",
                30);
        UUID adminId = UUID.randomUUID();

        String token = jwtService.issueAccessToken(adminId, "PLATFORM_ADMIN");
        Optional<PlatformAdminJwtService.AccessTokenClaims> claims = jwtService.validateAccessToken(token);

        assertTrue(claims.isPresent());
        assertEquals(adminId, claims.get().adminId());
        assertEquals("PLATFORM_ADMIN", claims.get().role());
    }

    @Test
    void rejectsATokenSignedWithADifferentSecret() {
        PlatformAdminJwtService issuer = new PlatformAdminJwtService("secret-one-that-is-long-enough-1234567", 30);
        PlatformAdminJwtService validator = new PlatformAdminJwtService("secret-two-that-is-long-enough-1234567",
                30);

        String token = issuer.issueAccessToken(UUID.randomUUID(), "PLATFORM_ADMIN");

        assertTrue(validator.validateAccessToken(token).isEmpty());
    }

    @Test
    void rejectsATamperedToken() {
        PlatformAdminJwtService jwtService = new PlatformAdminJwtService("a-test-secret-that-is-long-enough-1234",
                30);
        String token = jwtService.issueAccessToken(UUID.randomUUID(), "PLATFORM_ADMIN");

        assertTrue(jwtService.validateAccessToken(token + "tampered").isEmpty());
    }
}
