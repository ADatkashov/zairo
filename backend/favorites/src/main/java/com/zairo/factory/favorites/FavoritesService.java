package com.zairo.factory.favorites;

import com.zairo.factory.booking.AvailabilityStatus;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.favorites.FavoriteDtos.FavoriteProviderResponse;
import com.zairo.factory.favorites.FavoriteDtos.ServiceSummary;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class FavoritesService {

    private final FavoriteRepository favoriteRepository;
    private final ProviderRepository providerRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;

    public FavoritesService(FavoriteRepository favoriteRepository, ProviderRepository providerRepository,
            ServiceOfferingRepository serviceOfferingRepository,
            AvailabilitySlotRepository availabilitySlotRepository) {
        this.favoriteRepository = favoriteRepository;
        this.providerRepository = providerRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
    }

    /** Idempotent — favoriting an already-favorited provider is a no-op, not a 409. */
    @Transactional
    public void addFavorite(UUID userId, UUID providerId) {
        if (favoriteRepository.findByUserIdAndProviderId(userId, providerId).isPresent()) {
            return;
        }
        providerRepository.findById(providerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Provider not found: "
                        + providerId));
        favoriteRepository.save(new Favorite(UUID.randomUUID(), userId, providerId, Instant.now()));
    }

    /** Idempotent — removing a non-existent favorite is a no-op, not a 404. */
    @Transactional
    public void removeFavorite(UUID userId, UUID providerId) {
        favoriteRepository.deleteByUserIdAndProviderId(userId, providerId);
    }

    public boolean isFavorited(UUID userId, UUID providerId) {
        return favoriteRepository.findByUserIdAndProviderId(userId, providerId).isPresent();
    }

    public List<FavoriteProviderResponse> listFavorites(UUID userId) {
        return favoriteRepository.findByUserId(userId).stream()
                .map(fav -> providerRepository.findById(fav.getProviderId()).map(p -> toResult(p, fav.getCreatedAt())))
                .filter(Optional::isPresent)
                .map(Optional::get)
                .toList();
    }

    private FavoriteProviderResponse toResult(Provider provider, Instant favoritedAt) {
        List<ServiceOffering> services = serviceOfferingRepository.findByProviderIdAndActiveTrue(provider.getId());
        boolean hasOpenAvailability = availabilitySlotRepository.existsByProviderIdAndStatus(provider.getId(),
                AvailabilityStatus.OPEN);
        BigDecimal minPrice = services.stream().map(ServiceOffering::getPrice).min(Comparator.naturalOrder())
                .orElse(null);
        List<ServiceSummary> serviceSummaries = services.stream()
                .map(s -> new ServiceSummary(s.getId(), s.getTitle(), s.getDurationMinutes(), s.getPrice(),
                        s.getCurrency()))
                .toList();
        return new FavoriteProviderResponse(provider.getId(), provider.getName(), provider.getVertical(),
                provider.getStatus(), hasOpenAvailability, minPrice, serviceSummaries, favoritedAt);
    }
}
