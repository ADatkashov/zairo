package com.zairo.factory.auth;

import io.swagger.v3.oas.annotations.Hidden;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/**
 * The two domain-association files the OS fetches from the passkey RP-id
 * domain to confirm the app may use passkeys for it. Served by the backend
 * itself (so RP id = the backend's host needs no extra web hosting); each 404s
 * until configured. They must be public, un-redirected JSON.
 */
@RestController
@Hidden
public class WellKnownController {

    private final List<String> appleAppIds;
    private final String androidPackage;
    private final List<String> androidFingerprints;

    WellKnownController(@Value("${app.passkey.apple-app-ids:}") String appleAppIds,
            @Value("${app.passkey.android-package:}") String androidPackage,
            @Value("${app.passkey.android-sha256-fingerprints:}") String androidFingerprints) {
        this.appleAppIds = split(appleAppIds);
        this.androidPackage = androidPackage == null ? "" : androidPackage.trim();
        this.androidFingerprints = split(androidFingerprints);
    }

    /** iOS: {@code <TeamID>.<BundleID>} entries, e.g. {@code ABCDE12345.com.zairo}. */
    @GetMapping(value = "/.well-known/apple-app-site-association", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, Object> appleAppSiteAssociation() {
        if (appleAppIds.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        }
        return Map.of("webcredentials", Map.of("apps", appleAppIds));
    }

    @GetMapping(value = "/.well-known/assetlinks.json", produces = MediaType.APPLICATION_JSON_VALUE)
    public List<Map<String, Object>> assetLinks() {
        if (androidPackage.isEmpty() || androidFingerprints.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        }
        return List.of(Map.of("relation", List.of("delegate_permission/common.get_login_creds"), "target",
                Map.of("namespace", "android_app", "package_name", androidPackage, "sha256_cert_fingerprints",
                        androidFingerprints)));
    }

    private static List<String> split(String csv) {
        return csv == null ? List.of()
                : Arrays.stream(csv.split(",")).map(String::trim).filter(s -> !s.isEmpty()).toList();
    }
}
