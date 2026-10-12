-- Fourth catalog level for the biggest business types: subspheres
-- (Подсфера) between a business type and its services, e.g. Beauty Salon ->
-- Hair / Nails / Face & Makeup. Only business types with many services get
-- them; every service of those business types is assigned to a subsphere
-- (the V94 starter services, plus a few new ones where a subsphere would
-- otherwise be thin). Everything else keeps hanging directly off the
-- business type. All of it is editable in Platform Admin.
--
-- Idempotent: subspheres are keyed by their unique code, new services by
-- (business type, name_ru), and the assignment only touches services that
-- do not have a subsphere yet.

insert into subsphere (id, business_type_id, code, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), bt.id, v.code, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from (values
    ('beauty_salon', 'beauty_salon_hair', 'Шаш', 'Волосы', 'Hair', 1),
    ('beauty_salon', 'beauty_salon_nails', 'Тырнақ', 'Ногти', 'Nails', 2),
    ('beauty_salon', 'beauty_salon_face', 'Бет және макияж', 'Лицо и макияж', 'Face & Makeup', 3),
    ('beauty_salon', 'beauty_salon_brows_lashes', 'Қас және кірпік', 'Брови и ресницы', 'Brows & Lashes', 4),
    ('beauty_salon', 'beauty_salon_body', 'Дене және эпиляция', 'Тело и эпиляция', 'Body & Hair Removal', 5),
    ('auto_service', 'auto_service_diagnostics', 'Диагностика', 'Диагностика', 'Diagnostics', 1),
    ('auto_service', 'auto_service_maintenance', 'Қызмет көрсету', 'Обслуживание и ТО', 'Maintenance', 2),
    ('auto_service', 'auto_service_chassis_brakes', 'Жүріс бөлігі және тежегіш', 'Ходовая и тормоза', 'Suspension & Brakes', 3),
    ('auto_service', 'auto_service_engine', 'Қозғалтқыш', 'Двигатель', 'Engine', 4),
    ('auto_service', 'auto_service_climate', 'Климат', 'Кондиционер и климат', 'Climate', 5),
    ('apartment_renovation', 'apartment_renovation_whole_apartment', 'Пәтерді толық', 'Ремонт квартиры целиком', 'Whole Apartment', 1),
    ('apartment_renovation', 'apartment_renovation_rooms', 'Жекелеген бөлмелер', 'Ремонт отдельных помещений', 'Individual Rooms', 2),
    ('apartment_renovation', 'apartment_renovation_preparation', 'Дайындық жұмыстары', 'Подготовительные работы', 'Preparation', 3),
    ('finishing_works', 'finishing_works_walls_ceilings', 'Қабырға және төбе', 'Стены и потолки', 'Walls & Ceilings', 1),
    ('finishing_works', 'finishing_works_floors', 'Едендер', 'Полы', 'Floors', 2),
    ('finishing_works', 'finishing_works_doors_windows', 'Есік және терезе', 'Двери и окна', 'Doors & Windows', 3),
    ('dental_clinics', 'dental_clinics_prevention', 'Кеңес және профилактика', 'Консультация и профилактика', 'Consultation & Prevention', 1),
    ('dental_clinics', 'dental_clinics_treatment', 'Тісті емдеу', 'Лечение зубов', 'Treatment', 2),
    ('dental_clinics', 'dental_clinics_surgery_implants', 'Хирургия және имплантация', 'Хирургия и имплантация', 'Surgery & Implants', 3),
    ('dental_clinics', 'dental_clinics_prosthetics_ortho', 'Протездеу және ортодонтия', 'Протезирование и ортодонтия', 'Prosthetics & Orthodontics', 4),
    ('dental_clinics', 'dental_clinics_kids', 'Балалар стоматологиясы', 'Детская стоматология', 'Pediatric Dentistry', 5),
    ('diagnostic_centers', 'diagnostic_centers_radiology', 'Сәулелік диагностика', 'Лучевая диагностика', 'Radiology', 1),
    ('diagnostic_centers', 'diagnostic_centers_ultrasound_functional', 'УДЗ және функционалды', 'УЗИ и функциональная диагностика', 'Ultrasound & Functional', 2),
    ('diagnostic_centers', 'diagnostic_centers_endoscopy', 'Эндоскопия', 'Эндоскопия', 'Endoscopy', 3),
    ('diagnostic_centers', 'diagnostic_centers_programs', 'Кешенді бағдарламалар', 'Комплексные программы', 'Comprehensive Programs', 4),
    ('massage', 'massage_classic_therapeutic', 'Классикалық және емдік', 'Классический и лечебный', 'Classic & Therapeutic', 1),
    ('massage', 'massage_body_shaping', 'Дене пішінін түзеу', 'Коррекция фигуры', 'Body Shaping', 2),
    ('massage', 'massage_relax_sport', 'Релакс және спорт', 'Релакс и спорт', 'Relax & Sport', 3),
    ('massage', 'massage_kids', 'Балалар массажы', 'Детский массаж', 'Kids', 4),
    ('tutors', 'tutors_exact_sciences', 'Нақты және жаратылыстану', 'Точные и естественные науки', 'Math & Sciences', 1),
    ('tutors', 'tutors_languages', 'Тілдер', 'Языки', 'Languages', 2),
    ('tutors', 'tutors_humanities', 'Гуманитарлық', 'Гуманитарные науки', 'Humanities', 3),
    ('tutors', 'tutors_primary', 'Бастауыш сынып', 'Начальная школа', 'Primary School', 4),
    ('lawyers', 'lawyers_consultations', 'Кеңестер', 'Консультации', 'Consultations', 1),
    ('lawyers', 'lawyers_contracts_deals', 'Шарттар және мәмілелер', 'Договоры и сделки', 'Contracts & Deals', 2),
    ('lawyers', 'lawyers_courts_disputes', 'Соттар және даулар', 'Суды и споры', 'Courts & Disputes', 3),
    ('lawyers', 'lawyers_family_inheritance', 'Отбасылық және мұрагерлік', 'Семейное и наследственное право', 'Family & Inheritance', 4),
    ('fitness_clubs', 'fitness_clubs_memberships', 'Абонементтер', 'Абонементы и посещения', 'Memberships & Visits', 1),
    ('fitness_clubs', 'fitness_clubs_classes', 'Сабақтар', 'Занятия', 'Classes', 2),
    ('fitness_clubs', 'fitness_clubs_kids', 'Балаларға', 'Детям', 'Kids', 3)
) as v(bt_code, code, name_kk, name_ru, name_en, sort_order)
join business_type bt on bt.code = v.bt_code
where not exists (select 1 from subsphere s where s.code = v.code);

insert into catalog_service (id, business_type_id, name_kk, name_ru, name_en, sort_order, status, created_at, updated_at)
select gen_random_uuid(), bt.id, v.name_kk, v.name_ru, v.name_en, v.sort_order, 'ACTIVE', now(), now()
from (values
    ('beauty_salon', 'Мужская стрижка', 'Ерлер шаш қиюы', 'Men''s haircut', 8),
    ('beauty_salon', 'Кератиновое выпрямление', 'Кератинмен түзету', 'Keratin straightening', 9),
    ('beauty_salon', 'Коррекция бровей', 'Қасты түзету', 'Brow shaping', 10),
    ('beauty_salon', 'Окрашивание бровей', 'Қасты бояу', 'Brow tinting', 11),
    ('beauty_salon', 'Наращивание ресниц', 'Кірпікті ұзарту', 'Lash extensions', 12),
    ('beauty_salon', 'Массаж всего тела', 'Бүкіл дене массажы', 'Full-body massage', 13),
    ('beauty_salon', 'Шугаринг ног', 'Аяқ шугаринг', 'Leg sugaring', 14),
    ('beauty_salon', 'Лазерная эпиляция', 'Лазерлік эпиляция', 'Laser hair removal', 15),
    ('auto_service', 'Диагностика ходовой части', 'Жүріс бөлігін диагностикалау', 'Suspension diagnostics', 9),
    ('auto_service', 'Замена амортизаторов', 'Амортизаторларды ауыстыру', 'Shock absorber replacement', 10),
    ('auto_service', 'Замена тормозных дисков', 'Тежегіш дискілерін ауыстыру', 'Brake disc replacement', 11),
    ('auto_service', 'Заправка кондиционера', 'Кондиционерді толтыру', 'A/C recharge', 12)
) as v(bt_code, name_ru, name_kk, name_en, sort_order)
join business_type bt on bt.code = v.bt_code
where not exists (
    select 1 from catalog_service cs
    where cs.business_type_id = bt.id and cs.name_ru = v.name_ru
);

update catalog_service cs
set subsphere_id = s.id, updated_at = now()
from (values
    ('beauty_salon', 'beauty_salon_hair', 'Женская стрижка'),
    ('beauty_salon', 'beauty_salon_hair', 'Окрашивание волос'),
    ('beauty_salon', 'beauty_salon_hair', 'Укладка'),
    ('beauty_salon', 'beauty_salon_hair', 'Мужская стрижка'),
    ('beauty_salon', 'beauty_salon_hair', 'Кератиновое выпрямление'),
    ('beauty_salon', 'beauty_salon_nails', 'Маникюр'),
    ('beauty_salon', 'beauty_salon_nails', 'Педикюр'),
    ('beauty_salon', 'beauty_salon_face', 'Чистка лица'),
    ('beauty_salon', 'beauty_salon_face', 'Макияж'),
    ('beauty_salon', 'beauty_salon_brows_lashes', 'Коррекция бровей'),
    ('beauty_salon', 'beauty_salon_brows_lashes', 'Окрашивание бровей'),
    ('beauty_salon', 'beauty_salon_brows_lashes', 'Наращивание ресниц'),
    ('beauty_salon', 'beauty_salon_body', 'Массаж всего тела'),
    ('beauty_salon', 'beauty_salon_body', 'Шугаринг ног'),
    ('beauty_salon', 'beauty_salon_body', 'Лазерная эпиляция'),
    ('auto_service', 'auto_service_diagnostics', 'Компьютерная диагностика'),
    ('auto_service', 'auto_service_diagnostics', 'Диагностика ходовой части'),
    ('auto_service', 'auto_service_maintenance', 'Замена масла и фильтров'),
    ('auto_service', 'auto_service_maintenance', 'Техническое обслуживание (ТО)'),
    ('auto_service', 'auto_service_maintenance', 'Замена ремня ГРМ'),
    ('auto_service', 'auto_service_chassis_brakes', 'Ремонт ходовой части'),
    ('auto_service', 'auto_service_chassis_brakes', 'Замена тормозных колодок'),
    ('auto_service', 'auto_service_chassis_brakes', 'Замена амортизаторов'),
    ('auto_service', 'auto_service_chassis_brakes', 'Замена тормозных дисков'),
    ('auto_service', 'auto_service_engine', 'Ремонт двигателя'),
    ('auto_service', 'auto_service_climate', 'Ремонт кондиционера'),
    ('auto_service', 'auto_service_climate', 'Заправка кондиционера'),
    ('apartment_renovation', 'apartment_renovation_whole_apartment', 'Косметический ремонт'),
    ('apartment_renovation', 'apartment_renovation_whole_apartment', 'Капитальный ремонт'),
    ('apartment_renovation', 'apartment_renovation_whole_apartment', 'Ремонт под ключ'),
    ('apartment_renovation', 'apartment_renovation_whole_apartment', 'Евроремонт'),
    ('apartment_renovation', 'apartment_renovation_rooms', 'Ремонт ванной комнаты'),
    ('apartment_renovation', 'apartment_renovation_rooms', 'Ремонт кухни'),
    ('apartment_renovation', 'apartment_renovation_preparation', 'Демонтажные работы'),
    ('apartment_renovation', 'apartment_renovation_preparation', 'Замер и смета'),
    ('finishing_works', 'finishing_works_walls_ceilings', 'Отделка стен'),
    ('finishing_works', 'finishing_works_walls_ceilings', 'Монтаж гипсокартона'),
    ('finishing_works', 'finishing_works_walls_ceilings', 'Натяжные потолки'),
    ('finishing_works', 'finishing_works_floors', 'Укладка ламината'),
    ('finishing_works', 'finishing_works_floors', 'Укладка паркета'),
    ('finishing_works', 'finishing_works_floors', 'Установка плинтусов'),
    ('finishing_works', 'finishing_works_floors', 'Стяжка пола'),
    ('finishing_works', 'finishing_works_doors_windows', 'Установка дверей'),
    ('finishing_works', 'finishing_works_doors_windows', 'Установка окон'),
    ('dental_clinics', 'dental_clinics_prevention', 'Консультация стоматолога'),
    ('dental_clinics', 'dental_clinics_prevention', 'Профессиональная чистка зубов'),
    ('dental_clinics', 'dental_clinics_prevention', 'Отбеливание зубов'),
    ('dental_clinics', 'dental_clinics_treatment', 'Лечение кариеса'),
    ('dental_clinics', 'dental_clinics_treatment', 'Лечение пульпита'),
    ('dental_clinics', 'dental_clinics_treatment', 'Установка пломбы'),
    ('dental_clinics', 'dental_clinics_surgery_implants', 'Удаление зуба'),
    ('dental_clinics', 'dental_clinics_surgery_implants', 'Имплантация зубов'),
    ('dental_clinics', 'dental_clinics_prosthetics_ortho', 'Протезирование зубов'),
    ('dental_clinics', 'dental_clinics_prosthetics_ortho', 'Брекеты и элайнеры'),
    ('dental_clinics', 'dental_clinics_kids', 'Детская стоматология'),
    ('diagnostic_centers', 'diagnostic_centers_radiology', 'МРТ'),
    ('diagnostic_centers', 'diagnostic_centers_radiology', 'КТ'),
    ('diagnostic_centers', 'diagnostic_centers_radiology', 'Рентген'),
    ('diagnostic_centers', 'diagnostic_centers_radiology', 'Маммография'),
    ('diagnostic_centers', 'diagnostic_centers_ultrasound_functional', 'УЗИ'),
    ('diagnostic_centers', 'diagnostic_centers_ultrasound_functional', 'ЭКГ'),
    ('diagnostic_centers', 'diagnostic_centers_ultrasound_functional', 'ЭЭГ'),
    ('diagnostic_centers', 'diagnostic_centers_endoscopy', 'Эндоскопия'),
    ('diagnostic_centers', 'diagnostic_centers_programs', 'Комплексная диагностика'),
    ('massage', 'massage_classic_therapeutic', 'Классический массаж'),
    ('massage', 'massage_classic_therapeutic', 'Массаж спины'),
    ('massage', 'massage_classic_therapeutic', 'Массаж шейно-воротниковой зоны'),
    ('massage', 'massage_body_shaping', 'Антицеллюлитный массаж'),
    ('massage', 'massage_body_shaping', 'Лимфодренажный массаж'),
    ('massage', 'massage_relax_sport', 'Расслабляющий массаж'),
    ('massage', 'massage_relax_sport', 'Спортивный массаж'),
    ('massage', 'massage_relax_sport', 'Массаж всего тела'),
    ('massage', 'massage_kids', 'Детский массаж'),
    ('tutors', 'tutors_exact_sciences', 'Репетитор по математике'),
    ('tutors', 'tutors_exact_sciences', 'Репетитор по физике'),
    ('tutors', 'tutors_exact_sciences', 'Репетитор по химии и биологии'),
    ('tutors', 'tutors_languages', 'Репетитор по русскому языку'),
    ('tutors', 'tutors_languages', 'Репетитор по казахскому языку'),
    ('tutors', 'tutors_humanities', 'Репетитор по истории'),
    ('tutors', 'tutors_primary', 'Репетитор для начальных классов'),
    ('tutors', 'tutors_primary', 'Помощь с домашним заданием'),
    ('lawyers', 'lawyers_consultations', 'Консультация юриста'),
    ('lawyers', 'lawyers_consultations', 'Юридическая консультация онлайн'),
    ('lawyers', 'lawyers_contracts_deals', 'Составление договора'),
    ('lawyers', 'lawyers_contracts_deals', 'Юридическое сопровождение сделки'),
    ('lawyers', 'lawyers_courts_disputes', 'Представительство в суде'),
    ('lawyers', 'lawyers_courts_disputes', 'Претензия / исковое заявление'),
    ('lawyers', 'lawyers_family_inheritance', 'Семейные споры (развод, алименты)'),
    ('lawyers', 'lawyers_family_inheritance', 'Наследственные дела'),
    ('fitness_clubs', 'fitness_clubs_memberships', 'Разовое посещение'),
    ('fitness_clubs', 'fitness_clubs_memberships', 'Абонемент на месяц'),
    ('fitness_clubs', 'fitness_clubs_memberships', 'Абонемент на 3 месяца'),
    ('fitness_clubs', 'fitness_clubs_memberships', 'Годовой абонемент'),
    ('fitness_clubs', 'fitness_clubs_classes', 'Групповые занятия'),
    ('fitness_clubs', 'fitness_clubs_classes', 'Вводная тренировка'),
    ('fitness_clubs', 'fitness_clubs_kids', 'Детский абонемент')
) as m(bt_code, subsphere_code, name_ru)
join business_type bt on bt.code = m.bt_code
join subsphere s on s.code = m.subsphere_code
where cs.business_type_id = bt.id
  and cs.name_ru = m.name_ru
  and cs.subsphere_id is null;
