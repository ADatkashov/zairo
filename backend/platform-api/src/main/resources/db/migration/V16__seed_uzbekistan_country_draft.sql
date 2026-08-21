-- Proves the actual claim of the Factory Country Architecture document:
-- a second market is a config row, not a code change. DRAFT — not a real
-- launch, just evidence the schema/API/resolution logic added in V15
-- already supports a country nobody wrote Uzbekistan-specific code for.
insert into country (code, name, default_language, supported_languages, currency, timezone, number_format, date_format, status)
values ('UZ', 'Uzbekistan', 'uz', 'uz,ru,en', 'UZS', 'Asia/Tashkent', '1 000,50', 'dd.MM.yyyy', 'DRAFT');
