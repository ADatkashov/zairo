package com.zairo.factory.ads;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AdBannerRepository extends JpaRepository<AdBanner, UUID> {

    /** Active banners inside their window for a city (or for every city), in carousel order. */
    @Query("""
            select b from AdBanner b
            where b.status = com.zairo.factory.ads.AdStatus.ACTIVE
              and b.startsAt <= :now and b.endsAt > :now
              and (b.cityCode is null or b.cityCode = :city)
            order by b.sortOrder asc, b.createdAt desc
            """)
    List<AdBanner> findLive(@Param("now") Instant now, @Param("city") String city);

    /** Without a city: only the banners meant for everyone. */
    @Query("""
            select b from AdBanner b
            where b.status = com.zairo.factory.ads.AdStatus.ACTIVE
              and b.startsAt <= :now and b.endsAt > :now
              and b.cityCode is null
            order by b.sortOrder asc, b.createdAt desc
            """)
    List<AdBanner> findLiveForEveryCity(@Param("now") Instant now);

    List<AdBanner> findAllByOrderByCreatedAtDesc();
}
