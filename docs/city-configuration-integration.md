# City Configuration Integration Guide

Руководство по интеграции конфигурации городов в Backend и Frontend.

## Overview

- **Backend** работает на уровне **страны** (страна = инфраструктура)
- **Frontend** работает на уровне **города** (город = UI конфигурация)
- **Одна БД** на страну, но можно фильтровать по городам через `city_code`

## Backend Integration

### 1. Загрузить конфиги стран при старте

**Файл:** `backend/core/src/main/java/com/zairo/factory/core/config/CountryConfigurationLoader.java`

```java
@Component
@Configuration
@Log4j2
public class CountryConfigurationLoader {

    private String country;
    private Map<String, Object> countryConfig;

    @PostConstruct
    public void loadCountryConfig() {
        country = System.getenv("COUNTRY");
        if (country == null || country.isEmpty()) {
            country = "kz"; // Default to Kazakhstan
        }

        try {
            String configPath = "config/countries/" + country + ".yml";
            ClassPathResource resource = new ClassPathResource(configPath);
            
            YamlPropertiesFactoryBean yaml = new YamlPropertiesFactoryBean();
            yaml.setResources(resource);
            Properties props = yaml.getObject();
            
            log.info("✅ Loaded country config: " + country);
            log.info("Infrastructure DB: " + props.getProperty("infrastructure.database.url"));
        } catch (Exception e) {
            log.error("❌ Failed to load country config", e);
            throw new RuntimeException(e);
        }
    }

    public String getCountry() {
        return country;
    }

    public Map<String, Object> getConfig() {
        return countryConfig;
    }
}
```

### 2. Добавить City Entity для хранения в БД

**Файл:** `backend/core/src/main/java/com/zairo/factory/core/cities/City.java`

```java
@Entity
@Table(name = "cities")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class City {
    
    @Id
    private UUID id;
    
    @Column(unique = true, nullable = false)
    private String code; // 'almaty', 'shymkent', etc.
    
    private String name;
    private String nameKk;
    private String countryCode; // 'kz', 'ru', etc.
    
    private String timezone;
    private String currency;
    
    private BigDecimal latitude;
    private BigDecimal longitude;
    
    private Integer defaultSearchRadiusKm;
    
    @Column(columnDefinition = "boolean default true")
    private Boolean active;
    
    @CreationTimestamp
    private LocalDateTime createdAt;
}
```

### 3. Загрузить города из конфигов в БД при старте

**Файл:** `backend/core/src/main/java/com/zairo/factory/core/cities/CityInitializer.java`

```java
@Component
@Log4j2
@RequiredArgsConstructor
public class CityInitializer {
    
    private final CityRepository cityRepository;
    private final CountryConfigurationLoader countryLoader;

    @PostConstruct
    public void initializeCities() {
        String country = countryLoader.getCountry();
        
        try {
            // Load cities from YAML config
            YamlPropertiesFactoryBean yaml = new YamlPropertiesFactoryBean();
            yaml.setResources(new ClassPathResource("config/cities/almaty.yml"));
            // ... загрузить все города для страны
            
            List<City> cities = Arrays.asList(
                new City(UUID.randomUUID(), "almaty", "Almaty", "Алматы", 
                    country, "Asia/Almaty", "KZT", 
                    BigDecimal.valueOf(43.2380), BigDecimal.valueOf(77.0640), 50, true, null),
                new City(UUID.randomUUID(), "shymkent", "Shymkent", "Шымкент", 
                    country, "Asia/Almaty", "KZT", 
                    BigDecimal.valueOf(42.3087), BigDecimal.valueOf(69.5957), 50, true, null)
            );
            
            // Insert only if not exists
            for (City city : cities) {
                if (!cityRepository.existsByCode(city.getCode())) {
                    cityRepository.save(city);
                    log.info("✅ Initialized city: " + city.getCode());
                }
            }
        } catch (Exception e) {
            log.error("❌ Failed to initialize cities", e);
        }
    }
}
```

### 4. Создать контроллер для управления городами (Platform Admin)

**Файл:** `backend/platformadmin/src/main/java/com/zairo/factory/platformadmin/CityAdminController.java`

```java
@RestController
@RequestMapping("/api/admin/cities")
@RequiredArgsConstructor
@PlatformAdminRequired  // Only Platform Admins can access
public class CityAdminController {
    
    private final CityService cityService;
    
    // Get all cities
    @GetMapping
    public ResponseEntity<List<CityDto>> listCities(
        @RequestParam(required = false) String country
    ) {
        List<City> cities = cityService.findByCountry(country);
        return ResponseEntity.ok(cities.stream()
            .map(CityDto::fromEntity)
            .collect(Collectors.toList()));
    }
    
    // Create new city
    @PostMapping
    public ResponseEntity<CityDto> createCity(@RequestBody CreateCityRequest request) {
        City city = cityService.createCity(request);
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(CityDto.fromEntity(city));
    }
    
    // Update city
    @PutMapping("/{code}")
    public ResponseEntity<CityDto> updateCity(
        @PathVariable String code,
        @RequestBody UpdateCityRequest request
    ) {
        City city = cityService.updateCity(code, request);
        return ResponseEntity.ok(CityDto.fromEntity(city));
    }
    
    // Delete city
    @DeleteMapping("/{code}")
    public ResponseEntity<Void> deleteCity(@PathVariable String code) {
        cityService.deleteCity(code);
        return ResponseEntity.noContent().build();
    }
}
```

**Контроллер для публичного API:**

**Файл:** `backend/core/src/main/java/com/zairo/factory/core/cities/CityController.java`

```java
@RestController
@RequestMapping("/api/cities")
@RequiredArgsConstructor
public class CityController {
    
    private final CityService cityService;
    
    // Get all active cities
    @GetMapping
    public ResponseEntity<List<CityDto>> listCities(
        @RequestParam(required = false) String country
    ) {
        List<City> cities = cityService.findActiveByCountry(country);
        return ResponseEntity.ok(cities.stream()
            .map(CityDto::fromEntity)
            .collect(Collectors.toList()));
    }
    
    // Get city by code
    @GetMapping("/{code}")
    public ResponseEntity<CityDto> getCity(@PathVariable String code) {
        City city = cityService.findByCode(code);
        return ResponseEntity.ok(CityDto.fromEntity(city));
    }
}
```

### 5. Добавить фильтрацию по городу в обычные Controllers

**Пример:** `backend/providers/src/main/java/com/zairo/factory/providers/ProviderController.java`

```java
@RestController
@RequestMapping("/api/providers")
@RequiredArgsConstructor
public class ProviderController {
    
    private final ProviderService providerService;
    
    @GetMapping
    public ResponseEntity<List<ProviderDto>> listProviders(
        @RequestParam(required = false) String city,
        @RequestParam(required = false) Double latitude,
        @RequestParam(required = false) Double longitude,
        Pageable pageable
    ) {
        // Filter by city
        List<Provider> providers = providerService.findByCity(city, pageable);
        return ResponseEntity.ok(providers.stream()
            .map(ProviderDto::fromEntity)
            .collect(Collectors.toList()));
    }
}
```

### 6. Database Schema Changes

**Новая миграция:** `backend/platform-api/src/main/resources/db/migration/Vxx__add_cities_and_city_code.sql`

```sql
-- Create cities table
CREATE TABLE cities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    name_kk VARCHAR(255),
    country_code VARCHAR(2) NOT NULL,
    timezone VARCHAR(255) NOT NULL DEFAULT 'Asia/Almaty',
    currency VARCHAR(3) NOT NULL DEFAULT 'KZT',
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    default_search_radius_km INTEGER DEFAULT 50,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_cities_country ON cities(country_code);
CREATE INDEX idx_cities_active ON cities(active);

-- Add city_code to other tables
ALTER TABLE businesses ADD COLUMN city_code VARCHAR(255);
ALTER TABLE providers ADD COLUMN city_code VARCHAR(255);
ALTER TABLE services ADD COLUMN city_code VARCHAR(255);
ALTER TABLE bookings ADD COLUMN city_code VARCHAR(255);

-- Add foreign key constraints
ALTER TABLE businesses ADD CONSTRAINT fk_businesses_city 
    FOREIGN KEY (city_code) REFERENCES cities(code);
ALTER TABLE providers ADD CONSTRAINT fk_providers_city 
    FOREIGN KEY (city_code) REFERENCES cities(code);
ALTER TABLE services ADD CONSTRAINT fk_services_city 
    FOREIGN KEY (city_code) REFERENCES cities(code);
ALTER TABLE bookings ADD CONSTRAINT fk_bookings_city 
    FOREIGN KEY (city_code) REFERENCES cities(code);

-- Create indexes for city filtering
CREATE INDEX idx_businesses_city ON businesses(city_code);
CREATE INDEX idx_providers_city ON providers(city_code);
CREATE INDEX idx_services_city ON services(city_code);
CREATE INDEX idx_bookings_city ON bookings(city_code);

-- Insert initial cities for Kazakhstan
INSERT INTO cities (code, name, name_kk, country_code, timezone, currency, latitude, longitude, default_search_radius_km)
VALUES 
    ('almaty', 'Almaty', 'Алматы', 'KZ', 'Asia/Almaty', 'KZT', 43.2380, 77.0640, 50),
    ('almaty-region', 'Almaty Region', 'Түркістан облысы', 'KZ', 'Asia/Almaty', 'KZT', 45.0000, 77.5000, 100),
    ('shymkent', 'Shymkent', 'Шымкент', 'KZ', 'Asia/Almaty', 'KZT', 42.3087, 69.5957, 50);
```

## Frontend Integration

### 1. Загрузить конфиг города при старте приложения

**Файл:** `apps/user_app/lib/core/config/city_config.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:yaml/yaml.dart';

class CityConfig {
  final String code;
  final String name;
  final String nameKk;
  final String country;
  final String timezone;
  final String currency;
  final double latitude;
  final double longitude;
  final int defaultSearchRadiusKm;

  CityConfig({
    required this.code,
    required this.name,
    required this.nameKk,
    required this.country,
    required this.timezone,
    required this.currency,
    required this.latitude,
    required this.longitude,
    required this.defaultSearchRadiusKm,
  });

  static Future<CityConfig> load(String cityCode) async {
    try {
      // Get city from environment or parameter
      final configPath = 'assets/config/cities/$cityCode.yml';
      final yaml = rootBundle.loadString(configPath);
      final doc = loadYaml(await yaml);
      
      return CityConfig(
        code: doc['app']['city']['code'],
        name: doc['app']['city']['name'],
        nameKk: doc['app']['city']['name_kk'],
        country: doc['app']['city']['country'],
        timezone: doc['app']['city']['timezone'],
        currency: doc['app']['city']['currency'],
        latitude: doc['app']['geo']['latitude'],
        longitude: doc['app']['geo']['longitude'],
        defaultSearchRadiusKm: doc['app']['geo']['default-search-radius-km'],
      );
    } catch (e) {
      print('❌ Failed to load city config: $e');
      // Fallback to Almaty
      return CityConfig(
        code: 'almaty',
        name: 'Almaty',
        nameKk: 'Алматы',
        country: 'KZ',
        timezone: 'Asia/Almaty',
        currency: 'KZT',
        latitude: 43.2380,
        longitude: 77.0640,
        defaultSearchRadiusKm: 50,
      );
    }
  }
}
```

### 2. Создать City Provider с GetIt

**Файл:** `apps/user_app/lib/core/di/city_provider.dart`

```dart
import 'package:get_it/get_it.dart';
import 'package:flutter/foundation.dart';

class CityProvider {
  static Future<void> setup(String cityCode) async {
    final getIt = GetIt.instance;
    
    final cityConfig = await CityConfig.load(cityCode);
    getIt.registerSingleton<CityConfig>(cityConfig);
    
    print('✅ City initialized: ${cityConfig.name}');
  }

  static CityConfig get current {
    return GetIt.instance<CityConfig>();
  }
}
```

### 3. Инициализировать при старте приложения

**Файл:** `apps/user_app/lib/main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Get city from command-line argument or environment
  String city = const String.fromEnvironment('CITY', defaultValue: 'almaty');
  
  // Initialize city configuration
  await CityProvider.setup(city);
  
  runApp(const MyApp());
}
```

### 4. Использовать конфиг в приложении

```dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cityConfig = CityProvider.current;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${cityConfig.name} - ${cityConfig.nameKk}'),
      ),
      body: Column(
        children: [
          Text('City: ${cityConfig.code}'),
          Text('Country: ${cityConfig.country}'),
          Text('Currency: ${cityConfig.currency}'),
          Text('Timezone: ${cityConfig.timezone}'),
          Text('Search Radius: ${cityConfig.defaultSearchRadiusKm} km'),
        ],
      ),
    );
  }
}
```

### 5. Копировать конфиги в assets

**В pubspec.yaml:**

```yaml
assets:
  - config/cities/
  - config/countries/
```

**Команда копирования:**

```bash
# Скопировать конфиги в assets
cp -r config/cities apps/user_app/assets/config/
cp -r config/cities apps/business_admin/assets/config/
```

## Testing

### Backend тесты

```java
@SpringBootTest
class CityInitializerTest {
    
    @Autowired
    private CityRepository cityRepository;
    
    @Test
    void testCitiesInitialized() {
        List<City> cities = cityRepository.findAll();
        assertThat(cities).isNotEmpty();
        assertThat(cities).extracting("code")
            .contains("almaty", "shymkent");
    }
}
```

### Frontend тесты

```dart
void main() {
  group('CityConfig', () {
    test('loads almaty config correctly', () async {
      final config = await CityConfig.load('almaty');
      expect(config.code, 'almaty');
      expect(config.name, 'Almaty');
      expect(config.country, 'KZ');
    });
  });
}
```

## API Endpoints для работы с городами

```
GET  /api/cities                     - Список всех доступных городов (public)
GET  /api/cities/:code               - Конфиг конкретного города (public)
POST /api/admin/cities               - Создать новый город (Platform Admin only)
PUT  /api/admin/cities/:code         - Обновить город (Platform Admin only)
DELETE /api/admin/cities/:code       - Удалить город (Platform Admin only)
```

**Примечание:** POST/PUT/DELETE требуют Platform Admin роли. Реализовать через `@PlatformAdminRequired` аннотацию или проверку в контроллере.

## Migration Checklist

### Backend
- [ ] Создать миграцию `Vxx__add_cities_and_city_code.sql` с таблицей cities
- [ ] Создать City JPA entity (`backend/core/src/main/java/.../cities/City.java`)
- [ ] Создать CityRepository (extends JpaRepository)
- [ ] Создать CityService для управления городами
- [ ] Создать CityAdminController (`/api/admin/cities/*` — Platform Admin only)
- [ ] Создать CityController (`/api/cities/*` — public)
- [ ] Добавить `@PlatformAdminRequired` аннотацию на admin endpoints
- [ ] Обновить запросы в других сервисах для фильтрации по city_code
- [ ] Добавить тесты для city-specific логики
- [ ] Документировать в OpenAPI/Swagger

### Frontend
- [ ] Добавить API клиент для получения списка городов (`CityApi`)
- [ ] Создать CityProvider (GetIt) для инъекции city
- [ ] Создать UI для выбора города (если нужен)
- [ ] Инициализировать CityProvider при старте приложения
- [ ] Обновить экраны для использования текущего города
- [ ] Добавить тесты

### Безопасность
- [ ] Убедиться что POST/PUT/DELETE `/api/admin/cities/*` требуют Platform Admin роль
- [ ] Убедиться что обычные пользователи могут только читать города через `/api/cities`
- [ ] Добавить логирование операций с городами в audit log

## Future Improvements

- [ ] API для управления городами (CRUD) через админ панель
- [ ] Multi-language support для названий городов
- [ ] Geolocation для автоматического выбора города
- [ ] Analytics по городам
- [ ] Per-city analytics dashboard
- [ ] City-specific notifications и campaigns
