create table country (
    code varchar(2) primary key,
    name varchar(255) not null,
    default_language varchar(5) not null,
    supported_languages varchar(255) not null,
    currency varchar(3) not null,
    timezone varchar(64) not null,
    number_format varchar(32) not null,
    date_format varchar(32) not null,
    status varchar(20) not null
);

insert into country (code, name, default_language, supported_languages, currency, timezone, number_format, date_format, status)
values ('KZ', 'Kazakhstan', 'kk', 'kk,ru,en', 'KZT', 'Asia/Almaty', '1 000,50', 'dd.MM.yyyy', 'ACTIVE');
