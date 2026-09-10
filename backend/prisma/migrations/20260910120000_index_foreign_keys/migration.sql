-- Every foreign key gets an index.
--
-- PostgreSQL indexes the *referenced* side of a foreign key and not the
-- referencing side, so each of these 62 columns had none. Two things follow,
-- and the second is the one that bites in production:
--
--   1. A query filtering on the column — "her payment methods", "this
--      seller's products" — is a sequential scan.
--   2. Deleting or updating a parent row scans the ENTIRE child table to
--      enforce the constraint. Deleting one seller_offer_variant scanned
--      cart_items, guest_cart_items, inventory_reservations, room_candidates
--      and purchase_plan_items end to end; the hourly media sweeper scanned
--      every visual search row for each asset it removed; and closing one
--      account scanned a dozen tables that grow with the whole platform.
--
-- None of this is visible on a development database with a few thousand rows,
-- which is exactly why it survived to here.
CREATE INDEX "account_recovery_events_actor_id_idx" ON "account_recovery_events"("actor_id");
CREATE INDEX "ai_stylist_outfits_message_id_idx" ON "ai_stylist_outfits"("message_id");
CREATE INDEX "ai_stylist_recommendations_message_id_idx" ON "ai_stylist_recommendations"("message_id");
CREATE INDEX "bundle_items_offer_id_idx" ON "bundle_items"("offer_id");
CREATE INDEX "bundle_items_product_id_idx" ON "bundle_items"("product_id");
CREATE INDEX "cart_items_offer_variant_id_idx" ON "cart_items"("offer_variant_id");
CREATE INDEX "categories_size_chart_id_idx" ON "categories"("size_chart_id");
CREATE INDEX "challenge_deliveries_route_id_idx" ON "challenge_deliveries"("route_id");
CREATE INDEX "chat_reports_reporter_id_idx" ON "chat_reports"("reporter_id");
CREATE INDEX "chats_seller_id_idx" ON "chats"("seller_id");
CREATE INDEX "closet_gaps_filled_by_item_id_idx" ON "closet_gaps"("filled_by_item_id");
CREATE INDEX "closet_item_wears_look_wear_id_idx" ON "closet_item_wears"("look_wear_id");
CREATE INDEX "closet_items_brand_id_idx" ON "closet_items"("brand_id");
CREATE INDEX "closet_items_offer_id_idx" ON "closet_items"("offer_id");
CREATE INDEX "closet_items_variant_id_idx" ON "closet_items"("variant_id");
CREATE INDEX "closet_looks_source_outfit_id_idx" ON "closet_looks"("source_outfit_id");
CREATE INDEX "commerce_content_attributions_actor_id_idx" ON "commerce_content_attributions"("actor_id");
CREATE INDEX "commerce_content_attributions_product_id_idx" ON "commerce_content_attributions"("product_id");
CREATE INDEX "commerce_content_attributions_reshare_id_idx" ON "commerce_content_attributions"("reshare_id");
CREATE INDEX "commerce_content_comments_removed_by_id_idx" ON "commerce_content_comments"("removed_by_id");
CREATE INDEX "commerce_content_product_tags_source_order_item_id_idx" ON "commerce_content_product_tags"("source_order_item_id");
CREATE INDEX "commerce_content_reshares_coupon_id_idx" ON "commerce_content_reshares"("coupon_id");
CREATE INDEX "commerce_content_reshares_via_reshare_id_idx" ON "commerce_content_reshares"("via_reshare_id");
CREATE INDEX "commerce_content_versions_created_by_id_idx" ON "commerce_content_versions"("created_by_id");
CREATE INDEX "commerce_contents_removed_by_id_idx" ON "commerce_contents"("removed_by_id");
CREATE INDEX "commission_ledgers_rule_id_idx" ON "commission_ledgers"("rule_id");
CREATE INDEX "drop_products_product_id_idx" ON "drop_products"("product_id");
CREATE INDEX "guest_cart_items_offer_variant_id_idx" ON "guest_cart_items"("offer_variant_id");
CREATE INDEX "guest_sessions_device_key_id_idx" ON "guest_sessions"("device_key_id");
CREATE INDEX "inventory_reservations_offer_variant_id_idx" ON "inventory_reservations"("offer_variant_id");
CREATE INDEX "loyalty_rewards_coupon_id_idx" ON "loyalty_rewards"("coupon_id");
CREATE INDEX "orders_fx_rate_id_idx" ON "orders"("fx_rate_id");
CREATE INDEX "payment_methods_user_id_idx" ON "payment_methods"("user_id");
CREATE INDEX "products_created_by_seller_id_idx" ON "products"("created_by_seller_id");
CREATE INDEX "purchase_plan_items_candidate_id_idx" ON "purchase_plan_items"("candidate_id");
CREATE INDEX "purchase_plan_items_decision_id_idx" ON "purchase_plan_items"("decision_id");
CREATE INDEX "purchase_plan_items_offer_id_idx" ON "purchase_plan_items"("offer_id");
CREATE INDEX "purchase_plan_items_offer_variant_id_idx" ON "purchase_plan_items"("offer_variant_id");
CREATE INDEX "purchase_plans_order_id_idx" ON "purchase_plans"("order_id");
CREATE INDEX "referral_rewards_coupon_id_idx" ON "referral_rewards"("coupon_id");
CREATE INDEX "referrals_code_id_idx" ON "referrals"("code_id");
CREATE INDEX "resale_listings_product_id_idx" ON "resale_listings"("product_id");
CREATE INDEX "review_moderation_logs_product_review_id_idx" ON "review_moderation_logs"("product_review_id");
CREATE INDEX "review_moderation_logs_seller_review_id_idx" ON "review_moderation_logs"("seller_review_id");
CREATE INDEX "role_permissions_permission_id_idx" ON "role_permissions"("permission_id");
CREATE INDEX "room_candidates_added_by_id_idx" ON "room_candidates"("added_by_id");
CREATE INDEX "room_candidates_offer_id_idx" ON "room_candidates"("offer_id");
CREATE INDEX "room_candidates_offer_variant_id_idx" ON "room_candidates"("offer_variant_id");
CREATE INDEX "room_comments_member_id_idx" ON "room_comments"("member_id");
CREATE INDEX "room_events_actor_id_idx" ON "room_events"("actor_id");
CREATE INDEX "rooms_recipient_user_id_idx" ON "rooms"("recipient_user_id");
CREATE INDEX "shipments_zone_id_idx" ON "shipments"("zone_id");
CREATE INDEX "support_messages_author_id_idx" ON "support_messages"("author_id");
CREATE INDEX "trend_insights_category_id_idx" ON "trend_insights"("category_id");
CREATE INDEX "unmet_demand_signals_suggested_category_id_idx" ON "unmet_demand_signals"("suggested_category_id");
CREATE INDEX "user_role_assignments_role_id_idx" ON "user_role_assignments"("role_id");
CREATE INDEX "value_profiles_policy_id_idx" ON "value_profiles"("policy_id");
CREATE INDEX "visual_search_results_region_id_idx" ON "visual_search_results"("region_id");
CREATE INDEX "visual_search_sessions_query_asset_id_idx" ON "visual_search_sessions"("query_asset_id");
CREATE INDEX "visual_try_on_requests_result_asset_id_idx" ON "visual_try_on_requests"("result_asset_id");
CREATE INDEX "visual_try_on_requests_session_id_idx" ON "visual_try_on_requests"("session_id");
CREATE INDEX "visual_try_on_requests_source_asset_id_idx" ON "visual_try_on_requests"("source_asset_id");
