package com.zairo.factory.vertical.auto;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * A customer's car — owned by a Core {@code User}, not a {@code Provider}.
 * References the owner by id only, same as every other Core reference in
 * this module.
 */
@Entity
@Table(name = "auto_vehicle")
public class Vehicle {

    @Id
    private UUID id;

    @Column(name = "owner_user_id", nullable = false)
    private UUID ownerUserId;

    @Column(nullable = false)
    private String make;

    @Column(nullable = false)
    private String model;

    @Column(nullable = false)
    private int year;

    @Column(name = "license_plate", nullable = false)
    private String licensePlate;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected Vehicle() {
    }

    public Vehicle(UUID id, UUID ownerUserId, String make, String model, int year, String licensePlate,
            Instant createdAt) {
        this.id = id;
        this.ownerUserId = ownerUserId;
        this.make = make;
        this.model = model;
        this.year = year;
        this.licensePlate = licensePlate;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getOwnerUserId() {
        return ownerUserId;
    }

    public String getMake() {
        return make;
    }

    public String getModel() {
        return model;
    }

    public int getYear() {
        return year;
    }

    public String getLicensePlate() {
        return licensePlate;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
