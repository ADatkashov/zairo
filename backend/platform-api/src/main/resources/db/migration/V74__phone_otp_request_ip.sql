-- SMS abuse limits (see PhoneOtpService): remember which client IP asked
-- for each code so one IP can't burn SMS budget across many phone numbers.
alter table phone_otp add column request_ip varchar(64);

create index idx_phone_otp_request_ip_created_at on phone_otp (request_ip, created_at desc);
create index idx_phone_otp_created_at on phone_otp (created_at desc);
