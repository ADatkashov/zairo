package com.zairo.factory.services;

import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.services.ServiceOfferingDtos.ServiceResponse;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
public class ServiceOfferingController {

    private final ServiceOfferingRepository serviceOfferingRepository;

    public ServiceOfferingController(ServiceOfferingRepository serviceOfferingRepository) {
        this.serviceOfferingRepository = serviceOfferingRepository;
    }

    @PostMapping("/api/v1/providers/{providerId}/services")
    @ResponseStatus(HttpStatus.CREATED)
    public ServiceResponse create(@PathVariable UUID providerId, @RequestBody CreateServiceRequest request) {
        ServiceOffering service = new ServiceOffering(UUID.randomUUID(), providerId, request.title(),
                request.durationMinutes(), request.price(), request.currency(), true);
        return ServiceResponse.from(serviceOfferingRepository.save(service));
    }

    @GetMapping("/api/v1/providers/{providerId}/services")
    public List<ServiceResponse> listByProvider(@PathVariable UUID providerId) {
        return serviceOfferingRepository.findByProviderId(providerId).stream().map(ServiceResponse::from).toList();
    }

    @GetMapping("/api/v1/services/{id}")
    public ServiceResponse getById(@PathVariable UUID id) {
        return serviceOfferingRepository.findById(id).map(ServiceResponse::from)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service not found: " + id));
    }
}
