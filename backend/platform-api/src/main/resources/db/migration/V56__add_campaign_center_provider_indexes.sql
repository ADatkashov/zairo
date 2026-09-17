-- Campaign Center: a read-composition layer over smart_fill_campaign,
-- rebook_campaign, and reactivation_campaign (see campaigncenter's own
-- package-info.java). No new columns or tables -- PAUSED/CANCELLED are new
-- values of each table's existing `status varchar(20)` column, which has no
-- check constraint to update (see V51/V53/V54).
--
-- smart_fill_campaign already has idx_smart_fill_campaign_provider_id
-- (V51). rebook_campaign and reactivation_campaign never needed a
-- provider-scoped read before (see their own repositories' prior doc
-- comments) -- CampaignCenterService.list/stats now do, the same
-- "provider_id first, it's the selective predicate" shape as every other
-- provider-scoped index in this codebase.
create index idx_rebook_campaign_provider_id_created_at on rebook_campaign (provider_id, created_at);
create index idx_reactivation_campaign_provider_id_created_at on reactivation_campaign (provider_id, created_at);
