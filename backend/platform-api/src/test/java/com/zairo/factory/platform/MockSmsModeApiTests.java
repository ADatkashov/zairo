package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.auth.AuthDtos.PhonePasswordLoginRequest;
import com.zairo.factory.auth.AuthDtos.PhoneRegisterRequest;
import com.zairo.factory.auth.AuthDtos.PhoneResetPasswordRequest;
import com.zairo.factory.auth.AuthDtos.RequestPhoneOtpRequest;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/** The pre-production mock SMS mode (OTP_MOCK_CODE): one fixed code for every phone, and the app is told about it. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {"app.otp.mock-code=424242", "app.otp.resend-cooldown-seconds=0",
                "app.otp.max-requests-per-ip-per-hour=100000", "app.otp.daily-send-cap=1000000"})
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestNotifications.class, TestIdentityProviders.class})
class MockSmsModeApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private TestIdentityProviders.CapturedOtps capturedOtps;

    private static String uniqueKzPhone() {
        long suffix = Math.abs(UUID.randomUUID().getMostSignificantBits() % 10_000_000L);
        return String.format("+7700%07d", suffix);
    }

    @Test
    void smsModeTellsTheAppThatCodesAreMockedAndWhichCode() {
        Map<?, ?> mode = restTemplate.getForEntity("/api/v1/auth/phone/sms-mode", Map.class).getBody();

        assertThat(mode.get("mock")).isEqualTo(true);
        assertThat(mode.get("mockCode")).isEqualTo("424242");
    }

    @Test
    void registerLoginAndResetAllWorkWithTheFixedCode() {
        String phone = uniqueKzPhone();
        restTemplate.postForEntity("/api/v1/auth/phone/request-otp", new RequestPhoneOtpRequest(phone), Void.class);
        assertThat(capturedOtps.byPhone.get(phone)).isEqualTo("424242");

        ResponseEntity<Map> registered = restTemplate.postForEntity("/api/v1/auth/phone/register",
                new PhoneRegisterRequest(phone, "424242", "Mock User", "password123"), Map.class);
        assertThat(registered.getStatusCode()).isEqualTo(HttpStatus.OK);

        assertThat(restTemplate.postForEntity("/api/v1/auth/phone/login",
                new PhonePasswordLoginRequest(phone, "password123"), Map.class).getStatusCode())
                .isEqualTo(HttpStatus.OK);

        restTemplate.postForEntity("/api/v1/auth/phone/request-otp", new RequestPhoneOtpRequest(phone), Void.class);
        assertThat(restTemplate.postForEntity("/api/v1/auth/phone/reset-password",
                new PhoneResetPasswordRequest(phone, "424242", "newPassword1"), Void.class).getStatusCode())
                .isEqualTo(HttpStatus.NO_CONTENT);
    }

    @Test
    void aWrongCodeIsStillRejected() {
        String phone = uniqueKzPhone();
        restTemplate.postForEntity("/api/v1/auth/phone/request-otp", new RequestPhoneOtpRequest(phone), Void.class);

        ResponseEntity<Map> response = restTemplate.postForEntity("/api/v1/auth/phone/register",
                new PhoneRegisterRequest(phone, "111111", "Mock User", "password123"), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }
}
