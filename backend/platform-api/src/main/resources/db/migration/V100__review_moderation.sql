-- Review moderation. A business can report a review (one report per review); the platform decides: hide it (it then
-- counts nowhere — not in any average, ranking or public list — and can be restored) or dismiss the report (the review
-- stays and cannot be reported again). hidden_at null = visible.
alter table review add column report_reason text;
alter table review add column reported_at timestamptz;
alter table review add column report_resolved_at timestamptz;
alter table review add column hidden_at timestamptz;
alter table review add column hidden_reason text;
create index idx_review_reported_open on review (reported_at) where reported_at is not null;
