-- The platform's top-level marketplace taxonomy — 20 categories (beauty,
-- auto and cleaning already existed; this adds the other 17) plus the
-- "sphere" (business_type) breakdown under each, per the product owner's
-- own list. Deliberately no CatalogService ("Услуги") rows yet, matching
-- how beauty/auto/cleaning already work today (V25's own comment: real
-- providers/services get created by actual businesses, not seeded here) —
-- and no Subsphere content either, per the same "structure first, admin
-- fills in content later" call. gen_random_uuid() + a category-code
-- subquery (rather than V25/V39's literal ids) since nothing later in this
-- file needs to reference these rows by a specific id.

-- cleaning was seeded (V39) before this 20-category structure existed, at
-- sort_order 3 — now collides with auto's official position. Harmless
-- (sort_order has no uniqueness constraint) but cosmetically wrong; move it
-- past the 20 official categories so it doesn't visually tie with auto.
update category set sort_order = 21 where code = 'cleaning';

insert into category (id, code, name_kk, name_ru, name_en, icon, sort_order, status, created_at, updated_at) values
    (gen_random_uuid(), 'medicine', 'Медицина', 'Медицина', 'Medicine', '🦷', 2, 'ACTIVE', now(), now()),
    (gen_random_uuid(), 'home_repair', 'Үй және жөндеу', 'Дом и ремонт', 'Home & Repair', '🏠', 4, 'ACTIVE', now(), now()),
    (gen_random_uuid(), 'sport_fitness', 'Спорт және фитнес', 'Спорт и фитнес', 'Sport & Fitness', '🏋️', 5, 'ACTIVE', now(), now()),
    (gen_random_uuid(), 'education', 'Білім беру', 'Образование', 'Education', '📚', 6, 'ACTIVE', now(), now()),
    (gen_random_uuid(), 'kids', 'Балалар', 'Дети', 'Kids', '👶', 7, 'ACTIVE', now(), now()),
    (gen_random_uuid(), 'animals', 'Жануарлар', 'Животные', 'Animals', '🐕', 8, 'ACTIVE', now(), now()),
    (gen_random_uuid(), 'photo_video', 'Фото/видео', 'Фото/видео', 'Photo & Video', '📸', 9, 'ACTIVE', now(), now()),
    (gen_random_uuid(), 'weddings', 'Үйлену тойлары', 'Свадьбы', 'Weddings', '💍', 10, 'ACTIVE', now(), now()),
    (gen_random_uuid(), 'legal', 'Заң қызметтері', 'Юридические услуги', 'Legal Services', '⚖️', 11, 'ACTIVE', now(), now()),
    (gen_random_uuid(), 'it_digital', 'IT/Digital', 'IT/Digital', 'IT & Digital', '💻', 12, 'ACTIVE', now(), now()),
    (gen_random_uuid(), 'food', 'Тағам', 'Еда', 'Food', '🍰', 13, 'ACTIVE', now(), now()),
    (gen_random_uuid(), 'fashion', 'Сән', 'Fashion', 'Fashion', '👗', 14, 'ACTIVE', now(), now()),
    (gen_random_uuid(), 'real_estate', 'Жылжымайтын мүлік', 'Недвижимость', 'Real Estate', '🏡', 15, 'ACTIVE', now(), now()),
    (gen_random_uuid(), 'tourism', 'Туризм', 'Туризм', 'Tourism', '✈️', 16, 'ACTIVE', now(), now()),
    (gen_random_uuid(), 'household_services', 'Тұрмыстық қызметтер', 'Бытовые услуги', 'Household Services', '🧹', 17, 'ACTIVE', now(), now()),
    (gen_random_uuid(), 'entertainment', 'Ойын-сауық', 'Развлечения', 'Entertainment', '🎮', 18, 'ACTIVE', now(), now()),
    (gen_random_uuid(), 'business_services', 'Бизнес қызметтері', 'Бизнес-услуги', 'Business Services', '💼', 19, 'ACTIVE', now(), now()),
    (gen_random_uuid(), 'events', 'Іс-шаралар', 'Мероприятия', 'Events', '🎉', 20, 'ACTIVE', now(), now());

-- ---- Beauty (existing category, existing 'beauty_salon' business type) ----
insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), c.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from category c cross join (values
    ('hairdresser', 'Шаштараз', 'Парикмахерская', 'Hairdresser', 2),
    ('barbershop', 'Барбершоп', 'Барбершоп', 'Barbershop', 3),
    ('manicure_pedicure', 'Маникюр/педикюр', 'Маникюр/педикюр', 'Manicure/Pedicure', 4),
    ('nail_extension', 'Тырнақ ұзарту', 'Наращивание ногтей', 'Nail Extension', 5),
    ('cosmetology', 'Косметология', 'Косметология', 'Cosmetology', 6),
    ('aesthetic_cosmetology', 'Эстетикалық косметология', 'Эстетическая косметология', 'Aesthetic Cosmetology', 7),
    ('laser_hair_removal', 'Лазерлік эпиляция', 'Лазерная эпиляция', 'Laser Hair Removal', 8),
    ('sugaring_depilation', 'Шугаринг/депиляция', 'Шугаринг/депиляция', 'Sugaring/Depilation', 9),
    ('brows_lashes', 'Қас/кірпік', 'Брови/ресницы', 'Brows/Lashes', 10),
    ('makeup_artists', 'Визажистер', 'Визажисты', 'Makeup Artists', 11),
    ('massage', 'Массаж', 'Массаж', 'Massage', 12),
    ('spa', 'SPA', 'SPA', 'SPA', 13),
    ('solariums', 'Солярийлер', 'Солярии', 'Solariums', 14),
    ('tattoo_piercing', 'Тату/пирсинг', 'Тату/пирсинг', 'Tattoo/Piercing', 15),
    ('hair_extension', 'Шаш ұзарту', 'Hair-салоны/наращивание волос', 'Hair Extension', 16)
) as v(code, name_kk, name_ru, name_en, sort_order)
where c.code = 'beauty';

-- ---- Medicine ----
insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), c.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from category c cross join (values
    ('dental_clinics', 'Стоматологиялар', 'Стоматологии', 'Dental Clinics', 1),
    ('private_clinics', 'Жеке клиникалар', 'Частные клиники', 'Private Clinics', 2),
    ('medical_centers', 'Медициналық орталықтар', 'Медицинские центры', 'Medical Centers', 3),
    ('diagnostic_centers', 'Диагностикалық орталықтар', 'Диагностические центры', 'Diagnostic Centers', 4),
    ('medical_labs', 'Зертханалар/анализдер', 'Лаборатории/анализы', 'Labs/Tests', 5),
    ('ophthalmology', 'Офтальмология', 'Офтальмология', 'Ophthalmology', 6),
    ('dermatology', 'Дерматология', 'Дерматология', 'Dermatology', 7),
    ('medical_cosmetology', 'Медициналық косметология', 'Косметология', 'Medical Cosmetology', 8),
    ('gynecology', 'Гинекология', 'Гинекология', 'Gynecology', 9),
    ('urology', 'Урология', 'Урология', 'Urology', 10),
    ('cardiology', 'Кардиология', 'Кардиология', 'Cardiology', 11),
    ('neurology', 'Неврология', 'Неврология', 'Neurology', 12),
    ('ent', 'ЛОР', 'ЛОР', 'ENT', 13),
    ('pediatrics', 'Педиатрия', 'Педиатрия', 'Pediatrics', 14),
    ('physiotherapy', 'Физиотерапия', 'Физиотерапия', 'Physiotherapy', 15),
    ('rehabilitation', 'Оңалту', 'Реабилитация', 'Rehabilitation', 16)
) as v(code, name_kk, name_ru, name_en, sort_order)
where c.code = 'medicine';

-- ---- Auto (existing category, existing 'auto_service' business type) ----
insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), c.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from category c cross join (values
    ('tire_service', 'Шиномонтаж', 'Шиномонтаж', 'Tire Service', 2),
    ('car_wash', 'Автожуу', 'Автомойки', 'Car Wash', 3),
    ('detailing', 'Детейлинг', 'Детейлинг', 'Detailing', 4),
    ('auto_electrics', 'Автоэлектриктер', 'Автоэлектрики', 'Auto Electrics', 5),
    ('car_diagnostics', 'Автокөлік диагностикасы', 'Диагностика автомобилей', 'Car Diagnostics', 6),
    ('engine_repair', 'Қозғалтқышты жөндеу', 'Ремонт двигателя', 'Engine Repair', 7),
    ('transmission_repair', 'Беріліс қорабын жөндеу', 'Ремонт коробки передач', 'Transmission Repair', 8),
    ('body_repair', 'Кузовтық жөндеу', 'Кузовной ремонт', 'Body Repair', 9),
    ('car_painting', 'Бояу', 'Покраска', 'Car Painting', 10),
    ('tinting', 'Тонирование', 'Тонировка', 'Tinting', 11),
    ('alarm_installation', 'Дабыл орнату', 'Установка сигнализаций', 'Alarm Installation', 12),
    ('car_audio', 'Автодыбыс орнату', 'Установка автозвука', 'Car Audio Installation', 13),
    ('oil_change', 'Май ауыстыру', 'Замена масла', 'Oil Change', 14),
    ('wheel_alignment', 'Дөңгелек түзету', 'Развал-схождение', 'Wheel Alignment', 15),
    ('tow_truck', 'Эвакуатор', 'Эвакуатор', 'Tow Truck', 16),
    ('car_rental_auto', 'Автокөлік жалдау', 'Прокат автомобилей', 'Car Rental', 17)
) as v(code, name_kk, name_ru, name_en, sort_order)
where c.code = 'auto';

-- ---- Home & Repair ----
insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), c.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from category c cross join (values
    ('apartment_renovation', 'Пәтер жөндеу', 'Ремонт квартир', 'Apartment Renovation', 1),
    ('construction', 'Құрылыс', 'Строительство', 'Construction', 2),
    ('electricians', 'Электриктер', 'Электрики', 'Electricians', 3),
    ('plumbers', 'Сантехниктер', 'Сантехники', 'Plumbers', 4),
    ('gas_specialists', 'Газ мамандары', 'Газовые специалисты', 'Gas Specialists', 5),
    ('painting_works', 'Сырлау жұмыстары', 'Малярные работы', 'Painting Works', 6),
    ('tiling', 'Плитка төсеу', 'Плиточники', 'Tiling', 7),
    ('finishing_works', 'Әрлеу жұмыстары', 'Отделочники', 'Finishing Works', 8),
    ('welders', 'Дәнекерлеушілер', 'Сварщики', 'Welders', 9),
    ('furniture_makers', 'Жиһазшылар', 'Мебельщики', 'Furniture Makers', 10),
    ('furniture_assembly', 'Жиһаз жинау', 'Сборка мебели', 'Furniture Assembly', 11),
    ('furniture_manufacturing', 'Жиһаз жасау', 'Изготовление мебели', 'Furniture Manufacturing', 12),
    ('interior_design', 'Интерьер дизайны', 'Дизайн интерьера', 'Interior Design', 13),
    ('architects_home', 'Сәулетшілер', 'Архитекторы', 'Architects', 14),
    ('home_cleaning', 'Клининг', 'Клининг', 'Cleaning', 15),
    ('upholstery_cleaning', 'Жиһазды химиялық тазалау', 'Химчистка мебели', 'Upholstery Cleaning', 16),
    ('post_renovation_cleaning', 'Жөндеуден кейінгі тазалау', 'Уборка после ремонта', 'Post-Renovation Cleaning', 17),
    ('office_cleaning', 'Кеңсе тазалау', 'Уборка офисов', 'Office Cleaning', 18),
    ('landscaping', 'Бау-бақша/ландшафт', 'Садовники/ландшафт', 'Landscaping', 19)
) as v(code, name_kk, name_ru, name_en, sort_order)
where c.code = 'home_repair';

-- ---- Sport & Fitness ----
insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), c.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from category c cross join (values
    ('fitness_clubs', 'Фитнес-клубтар', 'Фитнес-клубы', 'Fitness Clubs', 1),
    ('gyms', 'Спортзалдар', 'Тренажёрные залы', 'Gyms', 2),
    ('personal_trainers', 'Жеке жаттықтырушылар', 'Персональные тренеры', 'Personal Trainers', 3),
    ('yoga', 'Йога', 'Йога', 'Yoga', 4),
    ('pilates', 'Пилатес', 'Пилатес', 'Pilates', 5),
    ('dance_sport', 'Билер', 'Танцы', 'Dance', 6),
    ('martial_arts', 'Жекпе-жек өнері', 'Боевые искусства', 'Martial Arts', 7),
    ('swimming', 'Жүзу', 'Плавание', 'Swimming', 8),
    ('football', 'Футбол', 'Футбол', 'Football', 9),
    ('tennis', 'Теннис', 'Теннис', 'Tennis', 10),
    ('boxing', 'Бокс', 'Бокс', 'Boxing', 11),
    ('stretching', 'Созылу', 'Растяжка', 'Stretching', 12),
    ('rehab_fitness', 'Оңалту фитнесі', 'Реабилитационный фитнес', 'Rehab Fitness', 13),
    ('kids_sports_sections', 'Балалар спорт секциялары', 'Спортивные секции для детей', 'Kids Sports Sections', 14)
) as v(code, name_kk, name_ru, name_en, sort_order)
where c.code = 'sport_fitness';

-- ---- Education ----
insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), c.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from category c cross join (values
    ('tutors', 'Репетиторлар', 'Репетиторы', 'Tutors', 1),
    ('language_schools', 'Тіл мектептері', 'Языковые школы', 'Language Schools', 2),
    ('foreign_language_teachers', 'Шет тілі мұғалімдері', 'Учителя иностранных языков', 'Foreign Language Teachers', 3),
    ('exam_prep', 'Емтиханға дайындық', 'Подготовка к экзаменам', 'Exam Prep', 4),
    ('school_prep', 'Мектепке дайындық', 'Подготовка к школе', 'School Prep', 5),
    ('kids_development_centers', 'Балалар даму орталықтары', 'Детские развивающие центры', 'Kids Development Centers', 6),
    ('music_schools', 'Музыка мектептері', 'Музыкальные школы', 'Music Schools', 7),
    ('dance_schools', 'Би мектептері', 'Танцевальные школы', 'Dance Schools', 8),
    ('programming_courses', 'Бағдарламалау', 'Программирование', 'Programming', 9),
    ('it_courses', 'IT-курстар', 'IT-курсы', 'IT Courses', 10),
    ('online_courses', 'Онлайн оқыту', 'Онлайн-обучение', 'Online Courses', 11),
    ('professional_courses', 'Кәсіби курстар', 'Профессиональные курсы', 'Professional Courses', 12)
) as v(code, name_kk, name_ru, name_en, sort_order)
where c.code = 'education';

-- ---- Kids ----
insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), c.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from category c cross join (values
    ('kindergartens', 'Балабақшалар', 'Детские сады', 'Kindergartens', 1),
    ('nannies', 'Күтушілер', 'Няни', 'Nannies', 2),
    ('kids_centers', 'Балалар орталықтары', 'Детские центры', 'Kids Centers', 3),
    ('kids_tutors', 'Балаларға репетитор', 'Репетиторы для детей', 'Tutors for Kids', 4),
    ('speech_therapists', 'Логопедтер', 'Логопеды', 'Speech Therapists', 5),
    ('child_psychologists', 'Балалар психологтары', 'Детские психологи', 'Child Psychologists', 6),
    ('developmental_classes', 'Дамыту сабақтары', 'Развивающие занятия', 'Developmental Classes', 7),
    ('kids_sports', 'Балалар спорты', 'Детские спортивные секции', 'Kids Sports', 8),
    ('kids_dance', 'Балалар билері', 'Детские танцы', 'Kids Dance', 9),
    ('kids_parties', 'Балалар мерекелері', 'Детские праздники', 'Kids Parties', 10),
    ('animators_kids', 'Аниматорлар', 'Аниматоры', 'Animators', 11)
) as v(code, name_kk, name_ru, name_en, sort_order)
where c.code = 'kids';

-- ---- Animals ----
insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), c.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from category c cross join (values
    ('vet_clinics', 'Ветеринариялық клиникалар', 'Ветеринарные клиники', 'Vet Clinics', 1),
    ('veterinarians', 'Ветеринарлар', 'Ветеринары', 'Veterinarians', 2),
    ('groomers', 'Грумерлер', 'Грумеры', 'Groomers', 3),
    ('pet_boarding', 'Жануарларды уақытша күту', 'Передержка животных', 'Pet Boarding', 4),
    ('dog_training', 'Ит дрессировкасы', 'Дрессировка', 'Dog Training', 5),
    ('dog_walking', 'Итті серуендету', 'Выгул собак', 'Dog Walking', 6),
    ('pet_sitters', 'Үй жануарларына күтуші', 'Зооняни', 'Pet Sitters', 7),
    ('pet_hotels', 'Зоо қонақүйлер', 'Зоогостиницы', 'Pet Hotels', 8)
) as v(code, name_kk, name_ru, name_en, sort_order)
where c.code = 'animals';

-- ---- Photo & Video ----
insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), c.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from category c cross join (values
    ('photographers', 'Фотографтар', 'Фотографы', 'Photographers', 1),
    ('videographers', 'Видеографтар', 'Видеографы', 'Videographers', 2),
    ('photo_studios', 'Студиялар', 'Студии', 'Studios', 3),
    ('wedding_photographers', 'Үйлену фотографтары', 'Свадебные фотографы', 'Wedding Photographers', 4),
    ('product_photography', 'Заттық түсіру', 'Предметная съёмка', 'Product Photography', 5),
    ('family_photography', 'Отбасылық түсіру', 'Семейная фотосъёмка', 'Family Photography', 6),
    ('kids_photography', 'Балалар түсірілімі', 'Детская фотосъёмка', 'Kids Photography', 7),
    ('drone_shooting', 'Дрондар', 'Дроны', 'Drone Shooting', 8),
    ('video_editing', 'Видео монтаждау', 'Монтаж видео', 'Video Editing', 9)
) as v(code, name_kk, name_ru, name_en, sort_order)
where c.code = 'photo_video';

-- ---- Weddings ----
insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), c.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from category c cross join (values
    ('wedding_organization', 'Той ұйымдастыру', 'Организация свадьбы', 'Wedding Organization', 1),
    ('banquet_halls', 'Банкет залдары', 'Банкетные залы', 'Banquet Halls', 2),
    ('wedding_restaurants', 'Мейрамханалар', 'Рестораны', 'Restaurants', 3),
    ('wedding_photographer', 'Той фотографы', 'Фотограф', 'Photographer', 4),
    ('wedding_videographer', 'Той видеографы', 'Видеограф', 'Videographer', 5),
    ('wedding_host', 'Той жүргізушісі', 'Ведущий', 'Host/Emcee', 6),
    ('wedding_dj', 'DJ', 'DJ', 'DJ', 7),
    ('wedding_decorator', 'Декоратор', 'Декоратор', 'Decorator', 8),
    ('florist', 'Флорист', 'Флорист', 'Florist', 9),
    ('wedding_salon', 'Той салоны', 'Свадебный салон', 'Wedding Salon', 10),
    ('wedding_makeup', 'Той визажисі', 'Визажист', 'Makeup Artist', 11),
    ('wedding_stylist', 'Той стилисі', 'Стилист', 'Stylist', 12),
    ('wedding_cake', 'Той торты', 'Торт', 'Cake', 13),
    ('wedding_transport', 'Той көлігі', 'Транспорт', 'Transport', 14),
    ('wedding_musicians', 'Музыканттар', 'Музыканты', 'Musicians', 15),
    ('wedding_animators', 'Аниматорлар', 'Аниматоры', 'Animators', 16)
) as v(code, name_kk, name_ru, name_en, sort_order)
where c.code = 'weddings';

-- ---- Legal Services ----
insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), c.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from category c cross join (values
    ('lawyers', 'Заңгерлер', 'Юристы', 'Lawyers', 1),
    ('advocates', 'Адвокаттар', 'Адвокаты', 'Advocates', 2),
    ('notaries', 'Нотариустар', 'Нотариусы', 'Notaries', 3),
    ('accountants', 'Бухгалтерлер', 'Бухгалтеры', 'Accountants', 4),
    ('tax_consultants', 'Салық кеңесшілері', 'Налоговые консультанты', 'Tax Consultants', 5),
    ('auditors', 'Аудиторлар', 'Аудиторы', 'Auditors', 6),
    ('financial_consultants', 'Қаржы кеңесшілері', 'Финансовые консультанты', 'Financial Consultants', 7),
    ('business_registration', 'Бизнесті тіркеу', 'Регистрация бизнеса', 'Business Registration', 8),
    ('migration_services', 'Миграциялық қызметтер', 'Миграционные услуги', 'Migration Services', 9),
    ('insurance_agents', 'Сақтандыру агенттері', 'Страховые агенты', 'Insurance Agents', 10),
    ('mortgage_brokers', 'Ипотекалық брокерлер', 'Ипотечные брокеры', 'Mortgage Brokers', 11)
) as v(code, name_kk, name_ru, name_en, sort_order)
where c.code = 'legal';

-- ---- IT & Digital ----
insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), c.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from category c cross join (values
    ('web_development', 'Сайт әзірлеу', 'Разработка сайтов', 'Web Development', 1),
    ('mobile_app_development', 'Мобильді қосымша әзірлеу', 'Разработка мобильных приложений', 'Mobile App Development', 2),
    ('ui_ux_design', 'UI/UX дизайн', 'UI/UX-дизайн', 'UI/UX Design', 3),
    ('graphic_design', 'Графикалық дизайн', 'Графический дизайн', 'Graphic Design', 4),
    ('seo', 'SEO', 'SEO', 'SEO', 5),
    ('smm', 'SMM', 'SMM', 'SMM', 6),
    ('digital_marketing', 'Digital-маркетинг', 'Digital-маркетинг', 'Digital Marketing', 7),
    ('content_makers', 'Контент-мейкерлер', 'Контент-мейкеры', 'Content Makers', 8),
    ('copywriters', 'Копирайтерлер', 'Копирайтеры', 'Copywriters', 9),
    ('translators_it', 'Аудармашылар', 'Переводчики', 'Translators', 10),
    ('it_consultants', 'IT-кеңесшілер', 'IT-консультанты', 'IT Consultants', 11),
    ('devops', 'DevOps', 'DevOps', 'DevOps', 12),
    ('sysadmins', 'Жүйелік әкімшілер', 'Системные администраторы', 'System Administrators', 13)
) as v(code, name_kk, name_ru, name_en, sort_order)
where c.code = 'it_digital';

-- ---- Food ----
insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), c.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from category c cross join (values
    ('catering', 'Кейтеринг', 'Кейтеринг', 'Catering', 1),
    ('chefs', 'Аспазшылар', 'Повара', 'Chefs', 2),
    ('private_chefs', 'Жеке аспазшылар', 'Частные повара', 'Private Chefs', 3),
    ('confectioners', 'Кондитерлер', 'Кондитеры', 'Confectioners', 4),
    ('custom_cakes', 'Тапсырыспен торттар', 'Торты на заказ', 'Custom Cakes', 5),
    ('baking', 'Наубайхана', 'Выпечка', 'Baking', 6),
    ('food_delivery', 'Тамақ жеткізу', 'Доставка еды', 'Food Delivery', 7),
    ('banquet_services', 'Банкет қызметтері', 'Банкетные услуги', 'Banquet Services', 8),
    ('food_trucks', 'Фудтректер', 'Фудтраки', 'Food Trucks', 9),
    ('cafes_with_booking', 'Брондалатын кафе/мейрамханалар', 'Кофейни/рестораны с бронированием', 'Cafes/Restaurants with Booking', 10)
) as v(code, name_kk, name_ru, name_en, sort_order)
where c.code = 'food';

-- ---- Fashion ----
insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), c.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from category c cross join (values
    ('tailoring_ateliers', 'Ательелер', 'Ателье', 'Tailoring Ateliers', 1),
    ('clothing_sewing', 'Киім тігу', 'Пошив одежды', 'Clothing Sewing', 2),
    ('clothing_alteration', 'Киімді жөндеу', 'Ремонт одежды', 'Clothing Alteration', 3),
    ('clothing_dry_cleaning', 'Киімді химиялық тазалау', 'Химчистка одежды', 'Clothing Dry Cleaning', 4),
    ('fashion_stylists', 'Стилистер', 'Стилисты', 'Stylists', 5),
    ('personal_shoppers', 'Жеке шопперлер', 'Персональные шоперы', 'Personal Shoppers', 6),
    ('image_consultants', 'Имидж-кеңесшілер', 'Имидж-консультанты', 'Image Consultants', 7),
    ('clothing_designers', 'Киім дизайнерлері', 'Дизайнеры одежды', 'Clothing Designers', 8),
    ('shoe_repair', 'Аяқ киімді жөндеу', 'Ремонт обуви', 'Shoe Repair', 9),
    ('shoe_making', 'Аяқ киім жасау', 'Изготовление обуви', 'Shoe Making', 10)
) as v(code, name_kk, name_ru, name_en, sort_order)
where c.code = 'fashion';

-- ---- Real Estate ----
insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), c.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from category c cross join (values
    ('realtors', 'Риелторлар', 'Риелторы', 'Realtors', 1),
    ('real_estate_agencies', 'Жылжымайтын мүлік агенттіктері', 'Агентства недвижимости', 'Real Estate Agencies', 2),
    ('property_sale', 'Жылжымайтын мүлік сату', 'Продажа недвижимости', 'Property Sale', 3),
    ('property_rental', 'Жылжымайтын мүлік жалдау', 'Аренда недвижимости', 'Property Rental', 4),
    ('property_management', 'Жылжымайтын мүлікті басқару', 'Управление недвижимостью', 'Property Management', 5),
    ('property_valuation', 'Жылжымайтын мүлікті бағалау', 'Оценка недвижимости', 'Property Valuation', 6),
    ('real_estate_lawyers', 'Жылжымайтын мүлік бойынша заңгерлер', 'Юристы по недвижимости', 'Real Estate Lawyers', 7),
    ('property_staging', 'Сатуға дайындау/дизайн', 'Дизайн/подготовка квартиры к продаже', 'Property Staging', 8)
) as v(code, name_kk, name_ru, name_en, sort_order)
where c.code = 'real_estate';

-- ---- Tourism ----
insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), c.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from category c cross join (values
    ('tour_operators', 'Туроператорлар', 'Туроператоры', 'Tour Operators', 1),
    ('travel_agents', 'Турагенттер', 'Туристические агенты', 'Travel Agents', 2),
    ('tour_guides', 'Гидтер', 'Гиды', 'Guides', 3),
    ('excursions', 'Экскурсиялар', 'Экскурсии', 'Excursions', 4),
    ('transfer_services', 'Трансфер', 'Трансфер', 'Transfer', 5),
    ('car_rental_travel', 'Автокөлік жалдау', 'Аренда автомобилей', 'Car Rental', 6),
    ('accommodation_rental', 'Тұрғын үй жалдау', 'Аренда жилья', 'Accommodation Rental', 7),
    ('trip_organization', 'Саяхат ұйымдастыру', 'Организация путешествий', 'Trip Organization', 8),
    ('photo_tours', 'Фототурлар', 'Фототуры', 'Photo Tours', 9),
    ('extreme_tourism', 'Экстремалды туризм', 'Экстремальный туризм', 'Extreme Tourism', 10)
) as v(code, name_kk, name_ru, name_en, sort_order)
where c.code = 'tourism';

-- ---- Household Services ----
insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), c.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from category c cross join (values
    ('appliance_repair', 'Техниканы жөндеу', 'Ремонт техники', 'Appliance Repair', 1),
    ('phone_repair', 'Телефон жөндеу', 'Ремонт телефонов', 'Phone Repair', 2),
    ('computer_repair', 'Компьютер жөндеу', 'Ремонт компьютеров', 'Computer Repair', 3),
    ('home_appliance_repair', 'Тұрмыстық техниканы жөндеу', 'Ремонт бытовой техники', 'Home Appliance Repair', 4),
    ('key_making', 'Кілт жасау', 'Изготовление ключей', 'Key Making', 5),
    ('courier_services', 'Курьерлік қызметтер', 'Курьерские услуги', 'Courier Services', 6),
    ('loaders', 'Жүк тасушылар', 'Грузчики', 'Loaders', 7),
    ('relocation_services', 'Көшіру қызметтері', 'Переезды', 'Relocation Services', 8),
    ('storage_services', 'Заттарды сақтау', 'Хранение вещей', 'Storage Services', 9),
    ('laundries', 'Кір жуу орындары', 'Прачечные', 'Laundries', 10),
    ('dry_cleaners', 'Химиялық тазалау', 'Химчистки', 'Dry Cleaners', 11),
    ('tool_sharpening', 'Құралдарды қайрау', 'Заточка инструментов', 'Tool Sharpening', 12)
) as v(code, name_kk, name_ru, name_en, sort_order)
where c.code = 'household_services';

-- ---- Entertainment ----
insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), c.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from category c cross join (values
    ('quests', 'Квесттер', 'Квесты', 'Quests', 1),
    ('karaoke', 'Караоке', 'Караоке', 'Karaoke', 2),
    ('bowling', 'Боулинг', 'Боулинг', 'Bowling', 3),
    ('billiards', 'Бильярд', 'Бильярд', 'Billiards', 4),
    ('vr_clubs', 'VR-клубтар', 'VR-клубы', 'VR Clubs', 5),
    ('gaming_clubs', 'Ойын клубтары', 'Игровые клубы', 'Gaming Clubs', 6),
    ('cinema', 'Кино', 'Кино', 'Cinema', 7),
    ('entertainment_centers', 'Ойын-сауық орталықтары', 'Развлекательные центры', 'Entertainment Centers', 8),
    ('amusement_parks', 'Саябақтар', 'Парки', 'Parks', 9),
    ('attractions', 'Атракциондар', 'Аттракционы', 'Attractions', 10),
    ('concert_venues', 'Концерт алаңдары', 'Концертные площадки', 'Concert Venues', 11)
) as v(code, name_kk, name_ru, name_en, sort_order)
where c.code = 'entertainment';

-- ---- Business Services ----
insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), c.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from category c cross join (values
    ('hr_recruiting', 'HR/рекрутинг', 'HR/рекрутинг', 'HR/Recruiting', 1),
    ('career_consultants', 'Мансап кеңесшілері', 'Карьерные консультанты', 'Career Consultants', 2),
    ('business_consultants', 'Бизнес-кеңесшілер', 'Бизнес-консультанты', 'Business Consultants', 3),
    ('business_coaches', 'Коучтар', 'Коучи', 'Coaches', 4),
    ('marketers', 'Маркетологтар', 'Маркетологи', 'Marketers', 5),
    ('pr_specialists', 'PR-мамандар', 'PR', 'PR Specialists', 6),
    ('translators_business', 'Аудармашылар', 'Переводчики', 'Translators', 7),
    ('business_designers', 'Дизайнерлер', 'Дизайнеры', 'Designers', 8),
    ('business_architects', 'Сәулетшілер', 'Архитекторы', 'Architects', 9),
    ('engineers', 'Инженерлер', 'Инженеры', 'Engineers', 10),
    ('surveyors', 'Геодезистер', 'Геодезисты', 'Surveyors', 11),
    ('appraisers', 'Бағалаушылар', 'Оценщики', 'Appraisers', 12)
) as v(code, name_kk, name_ru, name_en, sort_order)
where c.code = 'business_services';

-- ---- Events (a starter set — the source list folded most event work into
-- Weddings/Photo & Video; this category gets a modest set to build on) ----
insert into business_type (id, category_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), c.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from category c cross join (values
    ('event_organizers', 'Іс-шара ұйымдастырушылары', 'Организаторы мероприятий', 'Event Organizers', 1),
    ('corporate_events', 'Корпоративтік іс-шаралар', 'Корпоративные мероприятия', 'Corporate Events', 2),
    ('birthday_organizers', 'Туған күн ұйымдастыру', 'Организация дней рождения', 'Birthday Organizers', 3),
    ('event_decorators', 'Іс-шара декораторлары', 'Декораторы для мероприятий', 'Event Decorators', 4),
    ('sound_light_equipment', 'Дыбыс және жарық', 'Звук и свет', 'Sound & Light Equipment', 5),
    ('event_hosts_djs', 'Жүргізушілер мен DJ', 'Ведущие и диджеи', 'Hosts & DJs', 6)
) as v(code, name_kk, name_ru, name_en, sort_order)
where c.code = 'events';
