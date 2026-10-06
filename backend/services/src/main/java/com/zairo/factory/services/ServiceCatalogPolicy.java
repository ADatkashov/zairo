package com.zairo.factory.services;

import com.zairo.factory.catalog.CatalogService;
import com.zairo.factory.catalog.CatalogServiceRepository;
import com.zairo.factory.catalog.TaxonomyStatus;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

/**
 * Businesses don't invent their own services: what a provider can offer is the
 * platform-managed catalog (managed in the platform console). This is the one
 * place that rule is enforced, for create, update and re-linking.
 *
 * <p>The rule applies to a provider that has a catalog business type, as soon
 * as the platform has defined at least one ACTIVE catalog service for that
 * type. Until then (a brand-new type nobody has filled in yet) free text stays
 * allowed — otherwise a business would be unable to add anything at all —
 * and so does a provider created before the master catalog existed (no
 * business type). When the rule applies:
 * <ul>
 *   <li>a {@code catalogServiceId} is required;</li>
 *   <li>it must exist, be ACTIVE and belong to the provider's business type;</li>
 *   <li>the title must be one of that catalog service's own names (Kazakh,
 *       Russian or English) — so the offering can't be linked to one thing
 *       and described as another.</li>
 * </ul>
 */
@Component
public class ServiceCatalogPolicy {

    private final ProviderRepository providerRepository;
    private final CatalogServiceRepository catalogServiceRepository;

    public ServiceCatalogPolicy(ProviderRepository providerRepository,
            CatalogServiceRepository catalogServiceRepository) {
        this.providerRepository = providerRepository;
        this.catalogServiceRepository = catalogServiceRepository;
    }

    /**
     * Validates a create / update request and returns the catalog link to
     * store (null only where free text is still allowed).
     */
    public UUID resolveForSave(UUID providerId, String title, UUID catalogServiceId) {
        if (!catalogIsRequired(providerId)) {
            requireExistsIfGiven(catalogServiceId);
            return catalogServiceId;
        }
        CatalogService catalogService = requireUsableCatalogService(providerId, catalogServiceId);
        String trimmed = title == null ? "" : title.trim();
        if (!trimmed.equals(catalogService.getNameKk()) && !trimmed.equals(catalogService.getNameRu())
                && !trimmed.equals(catalogService.getNameEn())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "The title must be the catalog service's own name — businesses can't write their own service "
                            + "names. Expected one of: " + catalogService.getNameKk() + " / "
                            + catalogService.getNameRu() + " / " + catalogService.getNameEn());
        }
        return catalogService.getId();
    }

    /** Validates a re-link (PATCH /services/{id}/catalog-link) and returns the link to store. */
    public UUID resolveForLink(UUID providerId, UUID catalogServiceId) {
        if (!catalogIsRequired(providerId)) {
            requireExistsIfGiven(catalogServiceId);
            return catalogServiceId;
        }
        return requireUsableCatalogService(providerId, catalogServiceId).getId();
    }

    private boolean catalogIsRequired(UUID providerId) {
        Provider provider = providerRepository.findById(providerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Provider not found: " + providerId));
        UUID businessTypeId = provider.getBusinessTypeId();
        return businessTypeId != null && !catalogServiceRepository
                .findByBusinessTypeIdAndStatusOrderBySortOrderAsc(businessTypeId, TaxonomyStatus.ACTIVE).isEmpty();
    }

    private void requireExistsIfGiven(UUID catalogServiceId) {
        if (catalogServiceId != null && !catalogServiceRepository.existsById(catalogServiceId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND,
                    "Catalog service not found: " + catalogServiceId);
        }
    }

    private CatalogService requireUsableCatalogService(UUID providerId, UUID catalogServiceId) {
        if (catalogServiceId == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Pick the service from the catalog (catalogServiceId) — businesses can't add services of their "
                            + "own.");
        }
        CatalogService catalogService = catalogServiceRepository.findById(catalogServiceId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Catalog service not found: " + catalogServiceId));
        UUID businessTypeId = providerRepository.findById(providerId).orElseThrow().getBusinessTypeId();
        if (!businessTypeId.equals(catalogService.getBusinessTypeId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "This catalog service belongs to a different kind of business.");
        }
        if (catalogService.getStatus() != TaxonomyStatus.ACTIVE) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "This catalog service is not available any more — pick another one.");
        }
        return catalogService;
    }
}
