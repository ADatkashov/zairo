package com.zairo.factory.city;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "city")
public class City {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, unique = true)
    private String code;

    @Column(nullable = false)
    private String name;

    @Column(name = "name_kk")
    private String nameKk;

    @Column(name = "country_code", nullable = false)
    private String countryCode;

    @Column(nullable = false)
    private String timezone;

    @Column(nullable = false, length = 3)
    private String currency;

    @Column
    private Double latitude;

    @Column
    private Double longitude;

    @Column(name = "default_search_radius_km")
    private Integer defaultSearchRadiusKm;

    @Column(nullable = false)
    private Boolean active;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected City() {
    }

    public City(String code, String name, String nameKk, String countryCode, String timezone, String currency,
            Double latitude, Double longitude, Integer defaultSearchRadiusKm, Boolean active) {
        this.code = code;
        this.name = name;
        this.nameKk = nameKk;
        this.countryCode = countryCode;
        this.timezone = timezone;
        this.currency = currency;
        this.latitude = latitude;
        this.longitude = longitude;
        this.defaultSearchRadiusKm = defaultSearchRadiusKm != null ? defaultSearchRadiusKm : 50;
        this.active = active != null ? active : true;
        this.createdAt = Instant.now();
        this.updatedAt = Instant.now();
    }

    public UUID getId() {
        return id;
    }

    public String getCode() {
        return code;
    }

    public String getName() {
        return name;
    }

    public String getNameKk() {
        return nameKk;
    }

    public String getCountryCode() {
        return countryCode;
    }

    public String getTimezone() {
        return timezone;
    }

    public String getCurrency() {
        return currency;
    }

    public Double getLatitude() {
        return latitude;
    }

    public Double getLongitude() {
        return longitude;
    }

    public Integer getDefaultSearchRadiusKm() {
        return defaultSearchRadiusKm;
    }

    public Boolean getActive() {
        return active;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void update(String name, String nameKk, String timezone, String currency, Double latitude,
            Double longitude, Integer defaultSearchRadiusKm, Boolean active) {
        this.name = name;
        this.nameKk = nameKk;
        this.timezone = timezone;
        this.currency = currency;
        this.latitude = latitude;
        this.longitude = longitude;
        this.defaultSearchRadiusKm = defaultSearchRadiusKm != null ? defaultSearchRadiusKm : 50;
        this.active = active != null ? active : true;
        this.updatedAt = Instant.now();
    }
}
