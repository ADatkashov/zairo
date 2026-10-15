-- Where a tap on a banner without a video goes inside the app (REWARDS, SEARCH); null = nowhere.
alter table ad_banner add column link_target varchar(20);
