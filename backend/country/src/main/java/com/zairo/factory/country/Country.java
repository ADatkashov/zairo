package com.zairo.factory.country;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.List;

/**
 * One market. {@code code} is the natural key (ISO 3166-1 alpha-2), not a
 * generated id — a country is looked up by code everywhere, never by a
 * surrogate. {@code supportedLanguages} is stored as a plain comma-joined
 * column rather than a Postgres array or a join table: nothing queries
 * "which countries support kk" yet, so the simpler column earns its keep;
 * revisit if/when that changes.
 */
@Entity
@Table(name = "country")
public class Country {

    @Id
    @Column(length = 2)
    private String code;

    @Column(nullable = false)
    private String name;

    @Column(name = "default_language", nullable = false, length = 5)
    private String defaultLanguage;

    @Column(name = "supported_languages", nullable = false)
    private String supportedLanguagesCsv;

    @Column(nullable = false, length = 3)
    private String currency;

    @Column(nullable = false)
    private String timezone;

    @Column(name = "number_format", nullable = false)
    private String numberFormat;

    @Column(name = "date_format", nullable = false)
    private String dateFormat;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private CountryStatus status;

    protected Country() {
    }

    public Country(String code, String name, String defaultLanguage, List<String> supportedLanguages,
            String currency, String timezone, String numberFormat, String dateFormat, CountryStatus status) {
        this.code = code;
        this.name = name;
        this.defaultLanguage = defaultLanguage;
        this.supportedLanguagesCsv = String.join(",", supportedLanguages);
        this.currency = currency;
        this.timezone = timezone;
        this.numberFormat = numberFormat;
        this.dateFormat = dateFormat;
        this.status = status;
    }

    public String getCode() {
        return code;
    }

    public String getName() {
        return name;
    }

    public String getDefaultLanguage() {
        return defaultLanguage;
    }

    public List<String> getSupportedLanguages() {
        return List.of(supportedLanguagesCsv.split(","));
    }

    public String getCurrency() {
        return currency;
    }

    public String getTimezone() {
        return timezone;
    }

    public String getNumberFormat() {
        return numberFormat;
    }

    public String getDateFormat() {
        return dateFormat;
    }

    public CountryStatus getStatus() {
        return status;
    }
}
