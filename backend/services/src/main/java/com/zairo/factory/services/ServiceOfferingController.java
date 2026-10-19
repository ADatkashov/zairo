package com.zairo.factory.services;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.providers.OwnsProvider;
import com.zairo.factory.providers.ProviderOwnership;
import com.zairo.factory.users.UserRepository;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.services.ServiceOfferingDtos.LinkCatalogServiceRequest;
import com.zairo.factory.services.ServiceOfferingDtos.ServiceResponse;
import com.zairo.factory.services.ServiceOfferingDtos.UpdateServiceRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
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
@Tag(name = "Services")
public class ServiceOfferingController {

    private final ServiceOfferingRepository serviceOfferingRepository;
    private final ProviderOwnership providerOwnership;
    private final ServiceCatalogPolicy serviceCatalogPolicy;
    private final UserRepository userRepository;

    public ServiceOfferingController(ServiceOfferingRepository serviceOfferingRepository,
            ProviderOwnership providerOwnership, ServiceCatalogPolicy serviceCatalogPolicy,
            UserRepository userRepository) {
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.providerOwnership = providerOwnership;
        this.serviceCatalogPolicy = serviceCatalogPolicy;
        this.userRepository = userRepository;
    }

    @Operation(summary = "Add a service to a provider", description = """
            Owner-only. Created active by default. Businesses don't write their own services: once the \
            business's type has an active catalog, `catalogServiceId` is required and `title` must be one \
            of that catalog service's names (400 otherwise). See `ServiceCatalogPolicy`.""")
    @ApiResponse(responseCode = "201", description = "Service created")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/providers/{providerId}/services")
    @ResponseStatus(HttpStatus.CREATED)
    @OwnsProvider
    public ServiceResponse create(@Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @Valid @RequestBody CreateServiceRequest request) {
        UUID catalogServiceId = serviceCatalogPolicy.resolveForSave(providerId, request.title(),
                request.catalogServiceId());
        ServiceOffering service = new ServiceOffering(UUID.randomUUID(), providerId, request.title(),
                request.durationMinutes(), request.price(), request.currency(), true);
        service.linkCatalogService(catalogServiceId);
        return ServiceResponse.from(serviceOfferingRepository.save(service));
    }

    private String getUserCurrentCityCode() {
        try {
            UUID userId = CurrentUser.requireUserId();
            return userRepository.findById(userId)
                    .map(user -> user.getCurrentCityCode())
                    .orElse(null);
        } catch (Exception e) {
            return null;
        }
    }

    @Operation(summary = "List a provider's services", description = """
            Active services by default — a deactivated one (see DELETE below) drops out of both this \
            listing and Search. Pass `includeInactive=true` (used by Business Admin) to also see \
            deactivated services alongside a way to reactivate them. \
            For authenticated users, returns services from their selected city; \
            for unauthenticated users, returns all services. No authentication required.""")
    @ApiResponse(responseCode = "200", description = "Matching services")
    @GetMapping("/api/v1/providers/{providerId}/services")
    public List<ServiceResponse> listByProvider(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @Parameter(description = "Include deactivated services too.")
            @RequestParam(defaultValue = "false") boolean includeInactive) {
        List<ServiceOffering> services;
        if (includeInactive) {
            services = serviceOfferingRepository.findByProviderId(providerId);
        } else {
            String cityCode = getUserCurrentCityCode();
            if (cityCode != null) {
                services = serviceOfferingRepository.findByProviderIdAndCityCodeAndActiveTrue(providerId, cityCode);
            } else {
                services = serviceOfferingRepository.findByProviderIdAndActiveTrue(providerId);
            }
        }
        return services.stream().map(ServiceResponse::from).toList();
    }

    @Operation(summary = "Get a service by id")
    @ApiResponse(responseCode = "200", description = "The service")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @GetMapping("/api/v1/services/{id}")
    public ServiceResponse getById(@Parameter(description = "The service's id.") @PathVariable UUID id) {
        return serviceOfferingRepository.findById(id).map(ServiceResponse::from)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service not found: " + id));
    }

    @Operation(summary = "Update a service", description = "Owner-only. Replaces title/duration/price/currency "
            + "wholesale. Same catalog rule as creating a service.")
    @ApiResponse(responseCode = "200", description = "Service updated")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/api/v1/services/{id}")
    @OwnsService
    public ServiceResponse update(@Parameter(description = "The service's id.") @PathVariable UUID id,
            @Valid @RequestBody UpdateServiceRequest request) {
        ServiceOffering service = serviceOfferingRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service not found: " + id));
        UUID catalogServiceId = serviceCatalogPolicy.resolveForSave(service.getProviderId(), request.title(),
                request.catalogServiceId());
        service.update(request.title(), request.durationMinutes(), request.price(), request.currency());
        // No catalog service named (only possible where free text is still
        // allowed) keeps whatever link the offering already has.
        if (catalogServiceId != null) {
            service.linkCatalogService(catalogServiceId);
        }
        return ServiceResponse.from(serviceOfferingRepository.save(service));
    }

    @Operation(summary = "Deactivate a service (soft-delete)", description = "Owner-only, idempotent — calling "
            + "it again on an already-deactivated (or missing) service silently succeeds. Existing bookings "
            + "still reference this service by id; it just drops out of listings/Search until reactivated.")
    @ApiResponse(responseCode = "204", description = "Deactivated (or already was)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/services/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @OwnsService
    public void deactivate(@Parameter(description = "The service's id.") @PathVariable UUID id) {
        serviceOfferingRepository.findById(id).ifPresent(service -> {
            service.deactivate();
            serviceOfferingRepository.save(service);
        });
    }

    @Operation(summary = "Reactivate a service", description = "Owner-only, idempotent — undoes deactivate().")
    @ApiResponse(responseCode = "200", description = "Service reactivated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/services/{id}/reactivate")
    @OwnsService
    public ServiceResponse reactivate(@Parameter(description = "The service's id.") @PathVariable UUID id) {
        ServiceOffering service = serviceOfferingRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service not found: " + id));
        service.reactivate();
        return ServiceResponse.from(serviceOfferingRepository.save(service));
    }

    @Operation(summary = "Link (or unlink) this service to a master catalog entry", description = """
            Owner-only. Pass a real catalog.CatalogService id to link. Unlinking (null) is only possible \
            for a business that has no catalog to pick from - otherwise it is a 400, and the target must be an \
            ACTIVE catalog service of the business's own type. Linking lets Search match this offering \
            against the catalog entry's multilingual name, not just this offering's own title.""")
    @ApiResponse(responseCode = "200", description = "Link updated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", description = "The service, or the given catalog service id, doesn't exist.",
            ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/services/{id}/catalog-link")
    @OwnsService
    public ServiceResponse linkCatalogService(@Parameter(description = "The service's id.") @PathVariable UUID id,
            @Valid @RequestBody LinkCatalogServiceRequest request) {
        ServiceOffering service = serviceOfferingRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service not found: " + id));
        service.linkCatalogService(serviceCatalogPolicy.resolveForLink(service.getProviderId(),
                request.catalogServiceId()));
        return ServiceResponse.from(serviceOfferingRepository.save(service));
    }
}
