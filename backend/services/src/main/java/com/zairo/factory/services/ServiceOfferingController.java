package com.zairo.factory.services;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.providers.ProviderOwnership;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.services.ServiceOfferingDtos.ServiceResponse;
import com.zairo.factory.services.ServiceOfferingDtos.UpdateServiceRequest;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
public class ServiceOfferingController {

    private final ServiceOfferingRepository serviceOfferingRepository;
    private final ProviderOwnership providerOwnership;

    public ServiceOfferingController(ServiceOfferingRepository serviceOfferingRepository,
            ProviderOwnership providerOwnership) {
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.providerOwnership = providerOwnership;
    }

    /**
     * Deliberately NOT ownership-checked yet, unlike update/deactivate below
     * — creation is still exercised as a plain test fixture across most of
     * the *ApiTests suite (search/reviews/favorites/payments/...), none of
     * which care about auth. Locking down "who can create a service under a
     * provider" is a real gap worth closing, but retrofitting auth into
     * every one of those unrelated test files is a much bigger, separate
     * change from "the owner can't be impersonated when editing/deleting
     * something that already exists" — the actual risk this pass closes.
     */
    @PostMapping("/api/v1/providers/{providerId}/services")
    @ResponseStatus(HttpStatus.CREATED)
    public ServiceResponse create(@PathVariable UUID providerId, @RequestBody CreateServiceRequest request) {
        ServiceOffering service = new ServiceOffering(UUID.randomUUID(), providerId, request.title(),
                request.durationMinutes(), request.price(), request.currency(), true);
        return ServiceResponse.from(serviceOfferingRepository.save(service));
    }

    /** Only active services — a deactivated one (see deactivate() below) drops out of both this listing and search. */
    @GetMapping("/api/v1/providers/{providerId}/services")
    public List<ServiceResponse> listByProvider(@PathVariable UUID providerId) {
        return serviceOfferingRepository.findByProviderIdAndActiveTrue(providerId).stream().map(ServiceResponse::from)
                .toList();
    }

    @GetMapping("/api/v1/services/{id}")
    public ServiceResponse getById(@PathVariable UUID id) {
        return serviceOfferingRepository.findById(id).map(ServiceResponse::from)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service not found: " + id));
    }

    @PutMapping("/api/v1/services/{id}")
    public ServiceResponse update(@PathVariable UUID id, @RequestBody UpdateServiceRequest request,
            HttpServletRequest httpRequest) {
        ServiceOffering service = serviceOfferingRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service not found: " + id));
        providerOwnership.requireOwner(service.getProviderId(), CurrentUser.requireUserId(httpRequest));
        service.update(request.title(), request.durationMinutes(), request.price(), request.currency());
        return ServiceResponse.from(serviceOfferingRepository.save(service));
    }

    /** Soft-delete (active=false) — existing bookings still reference this service by id, see ServiceOffering.deactivate(). Idempotent. */
    @DeleteMapping("/api/v1/services/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deactivate(@PathVariable UUID id, HttpServletRequest httpRequest) {
        serviceOfferingRepository.findById(id).ifPresent(service -> {
            providerOwnership.requireOwner(service.getProviderId(), CurrentUser.requireUserId(httpRequest));
            service.deactivate();
            serviceOfferingRepository.save(service);
        });
    }
}
