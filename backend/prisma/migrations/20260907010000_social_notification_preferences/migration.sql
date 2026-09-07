-- Two preference columns for the social feed.
--
-- `in_app_social` covers likes, comments, reshares and new followers — the
-- feedback loop that makes publishing worth doing.
--
-- `in_app_moderation` names the softer half of moderation news (a report
-- resolved in her favour, a reinstatement). The removal notice itself
-- deliberately ignores it: a woman who muted likes has muted likes, not the
-- news that her page has changed.
ALTER TABLE "notification_preferences"
  ADD COLUMN "in_app_social" BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN "in_app_moderation" BOOLEAN NOT NULL DEFAULT TRUE;
