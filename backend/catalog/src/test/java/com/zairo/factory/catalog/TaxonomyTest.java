package com.zairo.factory.catalog;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** Plain unit test of the three taxonomy levels' edit and status rules -- no Spring context, no database. */
class TaxonomyTest {

    private static final Instant T0 = Instant.parse("2026-10-12T10:00:00Z");
    private static final Instant T1 = Instant.parse("2026-10-12T11:00:00Z");

    @Test
    void categoryWithoutAnIconStartsWithNullIcon() {
        Category c = new Category(UUID.randomUUID(), "beauty", "Сұлулық", "Красота", "Beauty", 1,
                TaxonomyStatus.ACTIVE, T0);

        assertThat(c.getIcon()).isNull();
        assertThat(c.getStatus()).isEqualTo(TaxonomyStatus.ACTIVE);
        assertThat(c.getCreatedAt()).isEqualTo(T0);
    }

    @Test
    void categoryUpdateReplacesNamesIconAndOrderButNotCodeOrCreationTime() {
        Category c = new Category(UUID.randomUUID(), "beauty", "a", "б", "c", "old", 1, TaxonomyStatus.ACTIVE, T0);

        c.update("Сұлулық", "Красота", "Beauty", "spa", 5, T1);

        assertThat(c.getNameKk()).isEqualTo("Сұлулық");
        assertThat(c.getNameRu()).isEqualTo("Красота");
        assertThat(c.getNameEn()).isEqualTo("Beauty");
        assertThat(c.getIcon()).isEqualTo("spa");
        assertThat(c.getSortOrder()).isEqualTo(5);
        assertThat(c.getCode()).isEqualTo("beauty");
        assertThat(c.getCreatedAt()).isEqualTo(T0);
    }

    @Test
    void categoryStatusCanMoveThroughAllStates() {
        Category c = new Category(UUID.randomUUID(), "auto", "a", "б", "c", 1, TaxonomyStatus.ACTIVE, T0);

        c.setStatus(TaxonomyStatus.INACTIVE, T1);
        assertThat(c.getStatus()).isEqualTo(TaxonomyStatus.INACTIVE);

        c.setStatus(TaxonomyStatus.ARCHIVED, T1);
        assertThat(c.getStatus()).isEqualTo(TaxonomyStatus.ARCHIVED);

        c.setStatus(TaxonomyStatus.ACTIVE, T1);
        assertThat(c.getStatus()).isEqualTo(TaxonomyStatus.ACTIVE);
    }

    @Test
    void businessTypeKeepsItsCategoryAndUpdatesOnlyNamesAndOrder() {
        UUID categoryId = UUID.randomUUID();
        BusinessType t = new BusinessType(UUID.randomUUID(), categoryId, "salon", "a", "б", "c", 1,
                TaxonomyStatus.ACTIVE, T0);

        t.update("Салон", "Салон", "Salon", 3, T1);
        t.setStatus(TaxonomyStatus.ARCHIVED, T1);

        assertThat(t.getCategoryId()).isEqualTo(categoryId);
        assertThat(t.getCode()).isEqualTo("salon");
        assertThat(t.getNameEn()).isEqualTo("Salon");
        assertThat(t.getSortOrder()).isEqualTo(3);
        assertThat(t.getStatus()).isEqualTo(TaxonomyStatus.ARCHIVED);
    }

    @Test
    void subsphereKeepsItsBusinessTypeAndUpdatesOnlyNamesAndOrder() {
        UUID typeId = UUID.randomUUID();
        Subsphere s = new Subsphere(UUID.randomUUID(), typeId, "hair", "a", "б", "c", 1, TaxonomyStatus.ACTIVE, T0);

        s.update("Шаш", "Волосы", "Hair", 2, T1);
        s.setStatus(TaxonomyStatus.INACTIVE, T1);

        assertThat(s.getBusinessTypeId()).isEqualTo(typeId);
        assertThat(s.getCode()).isEqualTo("hair");
        assertThat(s.getNameRu()).isEqualTo("Волосы");
        assertThat(s.getSortOrder()).isEqualTo(2);
        assertThat(s.getStatus()).isEqualTo(TaxonomyStatus.INACTIVE);
        assertThat(s.getCreatedAt()).isEqualTo(T0);
    }
}
