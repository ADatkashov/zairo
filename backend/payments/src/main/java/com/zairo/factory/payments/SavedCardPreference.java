package com.zairo.factory.payments;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** Whether the customer's next online payment should also save the card used. */
@Entity
@Table(name = "saved_card_preference")
public class SavedCardPreference {

    @Id
    @Column(name = "user_id")
    private UUID userId;

    @Column(name = "save_on_next_payment", nullable = false)
    private boolean saveOnNextPayment;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected SavedCardPreference() {
    }

    public SavedCardPreference(UUID userId, boolean saveOnNextPayment, Instant now) {
        this.userId = userId;
        this.saveOnNextPayment = saveOnNextPayment;
        this.updatedAt = now;
    }

    public boolean isSaveOnNextPayment() {
        return saveOnNextPayment;
    }

    void set(boolean value, Instant now) {
        this.saveOnNextPayment = value;
        this.updatedAt = now;
    }
}
