package com.zairo.factory.vertical.beauty;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "beauty_portfolio_item")
public class PortfolioItem {

    @Id
    private UUID id;

    @Column(name = "master_id", nullable = false)
    private UUID masterId;

    @Column(name = "image_url", nullable = false)
    private String imageUrl;

    @Column
    private String caption;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected PortfolioItem() {
    }

    public PortfolioItem(UUID id, UUID masterId, String imageUrl, String caption, Instant createdAt) {
        this.id = id;
        this.masterId = masterId;
        this.imageUrl = imageUrl;
        this.caption = caption;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getMasterId() {
        return masterId;
    }

    public String getImageUrl() {
        return imageUrl;
    }

    public String getCaption() {
        return caption;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
