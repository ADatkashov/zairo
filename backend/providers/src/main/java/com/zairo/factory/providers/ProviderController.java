package com.zairo.factory.providers;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.catalog.BusinessType;
import com.zairo.factory.catalog.BusinessTypeRepository;
import com.zairo.factory.catalog.CategoryRepository;
import com.zairo.factory.catalog.TaxonomyStatus;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.providers.ProviderDtos.ProviderResponse;
import com.zairo.factory.providers.ProviderDtos.UpdateProviderRequest;
import com.zairo.factory.providers.ProviderDtos.UpdateProviderStatusRequest;
import com.zairo.factory.subscriptions.SubscriptionLimitService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@Tag(name = "Providers")
public class ProviderController {

    private final ProviderRepository providerRepository;
    private final SubscriptionLimitService subscriptionLimitService;
    private final CategoryRepository categoryRepository;
    private final BusinessTypeRepository businessTypeRepository;
    private final ApplicationEventPublisher eventPublisher;

    public ProviderController(ProviderRepository providerRepository,
            SubscriptionLimitService subscriptionLimitService, CategoryRepository categoryRepository,
            BusinessTypeRepository businessTypeRepository, ApplicationEventPublisher eventPublisher) {
        this.providerRepository = providerRepository;
        this.subscriptionLimitService = subscriptionLimitService;
        this.categoryRepository = categoryRepository;
        this.businessTypeRepository = businessTypeRepository;
        this.eventPublisher = eventPublisher;
    }

    @Operation(summary = "Create a provider (salon)", description = "Owner-only: the caller must be "
            + "authenticated and must be the exact user named as `ownerUserId` — can't create a provider "
            + "\"owned\" by someone else. Always starts PENDING; invisible to Search until an ADMIN approves "
            + "it via PATCH /providers/{id}/status. Gated by the owner's subscription plan's provider-count "
            + "limit (see GET /subscriptions/me).")
    @ApiResponse(responseCode = "201", description = "Provider created, status PENDING")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "ownerUserId doesn't match the caller's own id.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "402", description = "The owner's subscription plan doesn't allow another "
            + "provider — upgrade to add more.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/providers")
    @ResponseStatus(HttpStatus.CREATED)
    public ProviderResponse create(@Valid @RequestBody CreateProviderRequest request, HttpServletRequest httpRequest) {
        UUID currentUserId = CurrentUser.requireUserId(httpRequest);
        if (!request.ownerUserId().equals(currentUserId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                    "Cannot create a provider owned by a different user");
        }
        subscriptionLimitService.checkCanCreateProvider(currentUserId,
                (int) providerRepository.countByOwnerUserId(currentUserId));
        // vertical historically maps to a Category (see the V25 seed:
        // Category.code = "beauty"/"auto", one level coarser than
        // BusinessType.code = "beauty_salon"/"auto_service"). Best-effort:
        // resolve via the category, then its lowest-sortOrder active
        // business type — exactly right while each category has exactly
        // one (today), a documented approximation once a category has
        // several. A vertical with no matching Category leaves
        // businessTypeId null rather than rejecting the request — vertical
        // remains the field every existing call site actually depends on.
        UUID businessTypeId = categoryRepository.findByCode(request.vertical())
                .flatMap(category -> businessTypeRepository
                        .findByCategoryIdAndStatusOrderBySortOrderAsc(category.getId(), TaxonomyStatus.ACTIVE)
                        .stream().findFirst())
                .map(BusinessType::getId)
                .orElse(null);
        Provider provider = new Provider(UUID.randomUUID(), request.ownerUserId(), request.name(),
                request.vertical(), ProviderStatus.PENDING, Instant.now(), request.latitude(),
                request.longitude(), businessTypeId);
        return ProviderResponse.from(providerRepository.save(provider));
    }

    @Operation(summary = "List providers", description = """
            Unfiltered by default (every provider regardless of moderation status) — this raw listing isn't \
            the customer-facing discovery path (that's **GET /search/providers**, which filters to ACTIVE \
            only). The optional `status` filter exists for the Business Admin moderation screen, e.g. \
            `?status=PENDING`. No authentication required.""")
    @ApiResponse(responseCode = "200", description = "Matching providers")
    @GetMapping("/api/v1/providers")
    public List<ProviderResponse> list(
            @Parameter(description = "Filter to one moderation status. Omit for every provider.")
            @RequestParam(required = false) ProviderStatus status) {
        List<Provider> providers = status == null ? providerRepository.findAll()
                : providerRepository.findByStatus(status);
        return providers.stream().map(ProviderResponse::from).toList();
    }

    @Operation(summary = "Get a provider by id")
    @ApiResponse(responseCode = "200", description = "The provider")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @GetMapping("/api/v1/providers/{id}")
    public ProviderResponse getById(@Parameter(description = "The provider's id.") @PathVariable UUID id,
            HttpServletRequest httpRequest) {
        Provider provider = providerRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Provider not found: " + id));
        // No-op today (nothing listens yet) — see the discovery ADR's
        // analytics-hooks section. viewerUserId is null for an anonymous
        // caller, not omitted — this endpoint doesn't require auth.
        eventPublisher.publishEvent(
                new ProviderViewedEvent(id, CurrentUser.optionalUserId(httpRequest).orElse(null)));
        return ProviderResponse.from(provider);
    }

    @Operation(summary = "Update a provider's name/location", description = "Owner-only. Name and location "
            + "only — status is changed exclusively via PATCH /providers/{id}/status, vertical is immutable "
            + "after creation.")
    @ApiResponse(responseCode = "200", description = "Provider updated")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller doesn't own this provider.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/api/v1/providers/{id}")
    public ProviderResponse update(@Parameter(description = "The provider's id.") @PathVariable UUID id,
            @Valid @RequestBody UpdateProviderRequest request, HttpServletRequest httpRequest) {
        Provider provider = providerRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Provider not found: " + id));
        UUID currentUserId = CurrentUser.requireUserId(httpRequest);
        if (!provider.getOwnerUserId().equals(currentUserId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "You do not own this provider: " + id);
        }
        provider.update(request.name(), request.latitude(), request.longitude());
        return ProviderResponse.from(providerRepository.save(provider));
    }

    @Operation(summary = "List a user's providers", description = "For the Business Admin app: \"which salons "
            + "does this owner manage.\" No authentication required.")
    @ApiResponse(responseCode = "200", description = "The owner's providers (empty list if none)")
    @GetMapping("/api/v1/users/{ownerUserId}/providers")
    public List<ProviderResponse> listByOwner(
            @Parameter(description = "The owning user's id.") @PathVariable UUID ownerUserId) {
        return providerRepository.findByOwnerUserId(ownerUserId).stream().map(ProviderResponse::from).toList();
    }

    @Operation(summary = "Approve, suspend, or reinstate a provider", description = """
            Admin-only moderation action. This is the only way a provider ever leaves PENDING — there's no \
            auto-approval anywhere. Search only surfaces ACTIVE providers, so an unapproved or suspended \
            provider still exists but is invisible to customer discovery either way.

            **Workflow**: `Create booking...` scenarios all assume the provider is already ACTIVE — this is \
            the step that gets it there.""")
    @ApiResponse(responseCode = "200", description = "Status updated")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't ADMIN.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/providers/{id}/status")
    public ProviderResponse updateStatus(@Parameter(description = "The provider's id.") @PathVariable UUID id,
            @Valid @RequestBody UpdateProviderStatusRequest request, HttpServletRequest httpRequest) {
        CurrentUser.requireAdmin(httpRequest);
        Provider provider = providerRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Provider not found: " + id));
        provider.updateStatus(request.status());
        return ProviderResponse.from(providerRepository.save(provider));
    }
}
