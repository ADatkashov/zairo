-- Lets multi-provider sign-in safely recognise "the same customer" across
-- methods. An email is only trusted as proof of identity when a provider
-- (Google/Facebook) vouched for it; an email typed into the password
-- registration form is just a claim. Without this flag, someone could
-- pre-register a victim's email with a password of their own and later
-- inherit the victim's Google/Facebook login (account pre-hijacking).
alter table app_user add column email_verified boolean not null default false;

-- Accounts created through Google/Facebook took their email from the
-- provider's verified claim and have never had a password credential.
update app_user u
   set email_verified = true
 where u.email is not null
   and not exists (select 1 from credential c where c.user_id = u.id)
   and exists (select 1 from user_identity i
                where i.user_id = u.id and i.provider in ('GOOGLE', 'FACEBOOK'));
