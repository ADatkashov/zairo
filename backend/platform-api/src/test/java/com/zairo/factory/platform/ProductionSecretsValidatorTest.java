package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

/**
 * Plain unit test, no Spring context -- {@link ProductionSecretsValidator}
 * takes its inputs through its constructor precisely so this doesn't need
 * one.
 */
class ProductionSecretsValidatorTest {

    private static final String REAL_SECRET = "a-real-generated-secret-that-is-definitely-not-the-dev-default";

    @Test
    void doesNothingWhenTheProdProfileIsNotActive() {
        MockEnvironment env = new MockEnvironment(); // no active profiles -- local dev/test default
        ProductionSecretsValidator validator = new ProductionSecretsValidator(env,
                ProductionSecretsValidator.DEV_JWT_SECRET, ProductionSecretsValidator.DEV_PLATFORM_ADMIN_JWT_SECRET,
                ProductionSecretsValidator.DEV_DB_PASSWORD, ProductionSecretsValidator.DEV_STORAGE_SECRET_KEY, "",
                "", "", "", "", "", "");

        assertThatCode(validator::run).doesNotThrowAnyException();
    }

    @Test
    void refusesToStartUnderProdProfileWithDevDefaultJwtSecret() {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("prod");
        ProductionSecretsValidator validator = new ProductionSecretsValidator(env,
                ProductionSecretsValidator.DEV_JWT_SECRET, REAL_SECRET, REAL_SECRET, REAL_SECRET, REAL_SECRET,
                REAL_SECRET, REAL_SECRET, REAL_SECRET, REAL_SECRET, "", "");

        assertThatThrownBy(validator::run).isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("JWT_SECRET").hasMessageContaining("dev-default");
    }

    @Test
    void refusesToStartUnderProdProfileWithABlankSecret() {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("prod");
        ProductionSecretsValidator validator = new ProductionSecretsValidator(env, "", REAL_SECRET, REAL_SECRET,
                REAL_SECRET, REAL_SECRET, REAL_SECRET, REAL_SECRET, REAL_SECRET, REAL_SECRET, "", "");

        assertThatThrownBy(validator::run).isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("JWT_SECRET").hasMessageContaining("not set");
    }

    @Test
    void reportsEveryStillDefaultSecretAtOnce() {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("prod");
        ProductionSecretsValidator validator = new ProductionSecretsValidator(env,
                ProductionSecretsValidator.DEV_JWT_SECRET, ProductionSecretsValidator.DEV_PLATFORM_ADMIN_JWT_SECRET,
                ProductionSecretsValidator.DEV_DB_PASSWORD, ProductionSecretsValidator.DEV_STORAGE_SECRET_KEY, "",
                "", "", "", "", "", "");

        assertThatThrownBy(validator::run).isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("JWT_SECRET").hasMessageContaining("PLATFORM_ADMIN_JWT_SECRET")
                .hasMessageContaining("DB_PASSWORD").hasMessageContaining("MINIO_SECRET_KEY")
                .hasMessageContaining("GOOGLE_OAUTH_CLIENT_IDS").hasMessageContaining("APPLE_CLIENT_IDS")
                .hasMessageContaining("TWILIO_ACCOUNT_SID")
                .hasMessageContaining("TWILIO_AUTH_TOKEN").hasMessageContaining("TWILIO_FROM");
    }

    @Test
    void startsCleanlyUnderProdProfileWithEveryRealSecretSet() {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("prod");
        ProductionSecretsValidator validator = new ProductionSecretsValidator(env, REAL_SECRET, REAL_SECRET,
                REAL_SECRET, REAL_SECRET, REAL_SECRET, REAL_SECRET, REAL_SECRET, REAL_SECRET, REAL_SECRET,
                "", "");

        assertThatCode(validator::run).doesNotThrowAnyException();
    }

    @Test
    void refusesToStartUnderProdProfileWithoutTwilio() {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("prod");
        ProductionSecretsValidator validator = new ProductionSecretsValidator(env, REAL_SECRET, REAL_SECRET,
                REAL_SECRET, REAL_SECRET, REAL_SECRET, REAL_SECRET, "", "", "", "", "");

        assertThatThrownBy(validator::run).isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("TWILIO_ACCOUNT_SID");
    }

    @Test
    void acceptsAMessagingServiceInPlaceOfAFromNumber() {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("prod");
        ProductionSecretsValidator validator = new ProductionSecretsValidator(env, REAL_SECRET, REAL_SECRET,
                REAL_SECRET, REAL_SECRET, REAL_SECRET, REAL_SECRET, REAL_SECRET, REAL_SECRET, "",
                REAL_SECRET, "");

        assertThatCode(validator::run).doesNotThrowAnyException();
    }

    @Test
    void aMockedSmsCodeLetsProdStartWithoutTwilio() {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("prod");
        ProductionSecretsValidator validator = new ProductionSecretsValidator(env, REAL_SECRET, REAL_SECRET,
                REAL_SECRET, REAL_SECRET, REAL_SECRET, REAL_SECRET, "", "", "", "", "123456");

        assertThatCode(validator::run).doesNotThrowAnyException();
    }

    @Test
    void theMockDoesNotExcuseOtherMissingSecrets() {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("prod");
        ProductionSecretsValidator validator = new ProductionSecretsValidator(env,
                ProductionSecretsValidator.DEV_JWT_SECRET, REAL_SECRET, REAL_SECRET, REAL_SECRET, REAL_SECRET,
                REAL_SECRET, "", "", "", "", "123456");

        assertThatThrownBy(validator::run).isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("JWT_SECRET");
    }
}
