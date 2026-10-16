-- The "your visit is tomorrow" reminder (the one-hour reminder is reminder_sent_at). Guards against sending it twice.
alter table booking add column day_reminder_sent_at timestamptz;
