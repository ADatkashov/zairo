-- Optional second rating on a review: how the visit was with the person (master, mechanic, ...) themselves, as
-- opposed to the business. Null = the customer gave one rating only, which then counts for the person too.
alter table review add column worker_rating integer;
alter table review add constraint review_worker_rating_range check (worker_rating is null or worker_rating between 1 and 5);
