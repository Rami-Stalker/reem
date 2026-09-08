-- The frequency cap runs on every marketing send.
--
-- It asks one question — how much marketing has this woman had in the last day
-- and the last week — and the existing (user_id, status) index answers it by
-- reading every delivery she has ever had and filtering. Fine at a thousand
-- customers; not fine at the volume the cap exists to protect them from.
CREATE INDEX IF NOT EXISTS "notification_deliveries_user_id_category_sent_at_idx"
  ON "notification_deliveries" ("user_id", "category", "sent_at");
