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
import org.springframework.web.bind.annotation.RequestParam;
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

    /** Owner-only. */
    @PostMapping("/api/v1/providers/{providerId}/services")
    @ResponseStatus(HttpStatus.CREATED)
    public ServiceResponse create(@PathVariable UUID providerId, @RequestBody CreateServiceRequest request,
            HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
        ServiceOffering service = new ServiceOffering(UUID.randomUUID(), providerId, request.title(),
                request.durationMinutes(), request.price(), request.currency(), true);
        return ServiceResponse.from(serviceOfferingRepository.save(service));
    }

    /**
     * Active services by default — a deactivated one (see deactivate()
     * below) drops out of both this listing and search. Business Admin
     * passes includeInactive=true to also show deactivated services (with
     * a reactivate action); nothing else needs to see them.
     */
    @GetMapping("/api/v1/providers/{providerId}/services")
    public List<ServiceResponse> listByProvider(@PathVariable UUID providerId,
            @RequestParam(defaultValue = "false") boolean includeInactive) {
        List<ServiceOffering> services = includeInactive ? serviceOfferingRepository.findByProviderId(providerId)
                : serviceOfferingRepository.findByProviderIdAndActiveTrue(providerId);
        return services.stream().map(ServiceResponse::from).toList();
    }

    @GetMapping("/api/v1/services/{id}")
    public ServiceResponse getById(@PathVariable UUID id) {
        return serviceOfferingRepository.findById(id).map(ServiceResponse::from)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service not found: " + id));
    }

    /** Owner-only. */
    @PutMapping("/api/v1/services/{id}")
    public ServiceResponse update(@PathVariable UUID id, @RequestBody UpdateServiceRequest request,
            HttpServletRequest httpRequest) {
        ServiceOffering service = serviceOfferingRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service not found: " + id));
        providerOwnership.requireOwner(service.getProviderId(), CurrentUser.requireUserId(httpRequest));
        service.update(request.title(), request.durationMinutes(), request.price(), request.currency());
        return ServiceResponse.from(serviceOfferingRepository.save(service));
    }

    /** Soft-delete (active=false) — existing bookings still reference this service by id, see ServiceOffering.deactivate(). Owner-only, idempotent. */
    @DeleteMapping("/api/v1/services/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deactivate(@PathVariable UUID id, HttpServletRequest httpRequest) {
        serviceOfferingRepository.findById(id).ifPresent(service -> {
            providerOwnership.requireOwner(service.getProviderId(), CurrentUser.requireUserId(httpRequest));
            service.deactivate();
            serviceOfferingRepository.save(service);
        });
    }

    /** Owner-only, idempotent — undoes deactivate(). */
    @PostMapping("/api/v1/services/{id}/reactivate")
    public ServiceResponse reactivate(@PathVariable UUID id, HttpServletRequest httpRequest) {
        ServiceOffering service = serviceOfferingRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service not found: " + id));
        providerOwnership.requireOwner(service.getProviderId(), CurrentUser.requireUserId(httpRequest));
        service.reactivate();
        return ServiceResponse.from(serviceOfferingRepository.save(service));
    }
}
