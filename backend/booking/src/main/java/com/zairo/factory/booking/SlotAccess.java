package com.zairo.factory.booking;

import com.zairo.factory.providers.ProviderOwnership;
import java.util.UUID;
import org.springframework.stereotype.Component;

/** Backs {@link OwnsSlot}: ownership of a slot is ownership of the business it belongs to. */
@Component
public class SlotAccess {

    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final ProviderOwnership providerOwnership;

    SlotAccess(AvailabilitySlotRepository availabilitySlotRepository, ProviderOwnership providerOwnership) {
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.providerOwnership = providerOwnership;
    }

    /** Always {@code true}; a refusal is the exception (401 / 403). */
    public boolean requireCurrentOwner(UUID slotId) {
        var slot = availabilitySlotRepository.findById(slotId);
        if (slot.isPresent()) {
            return providerOwnership.requireCurrentOwner(slot.get().getProviderId());
        }
        return true;
    }
}
