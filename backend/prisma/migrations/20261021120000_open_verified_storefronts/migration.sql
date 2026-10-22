-- Open the storefronts that approval never opened.
--
-- `20260906190000_content_author_rename` made every non-customer page public,
-- "because a storefront nobody may look at is not a storefront" — but only for
-- the accounts that existed then. Sellers approved afterwards kept the customer
-- default, so their posts were hidden from shoppers' feeds and from every page
-- they were added to. Approval now opens the page; this catches up the rest.
UPDATE "users"
   SET "profile_is_public" = TRUE,
       "profile_public_since" = COALESCE("seller_verified_at", "created_at")
 WHERE "profile_is_public" = FALSE
   AND (
         ("role" = 'SELLER' AND "seller_verified_at" IS NOT NULL)
      OR "role" NOT IN ('CUSTOMER', 'SELLER')
       );

-- The denormalised mirrors move with the flag, as `setProfileVisibility` does.
UPDATE "commerce_contents" c
   SET "author_is_public" = TRUE
  FROM "users" u
 WHERE u."id" = c."author_id"
   AND u."profile_is_public"
   AND c."author_is_public" = FALSE;

UPDATE "commerce_content_reshares" r
   SET "resharer_is_public" = TRUE
  FROM "users" u
 WHERE u."id" = r."resharer_id"
   AND u."profile_is_public"
   AND r."resharer_is_public" = FALSE;
