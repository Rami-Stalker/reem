-- Syria's new lira: every stored Syrian-pound figure loses two zeros.
--
-- The redenomination is a change of unit, not of value: 1,450,000 ل.س becomes
-- 14,500 ل.س and buys the same dress. Prices, orders, wallets, the ledger, the
-- payout queue and the exchange rate all have to move on the same beat, or the
-- books stop balancing — a ledger entry whose debit was converted and whose
-- credit was not is a broken invariant, not a rounding difference.
--
-- Three rules decide what is touched:
--
--   1. A table with a `currency` column is converted only where it says SYP.
--      USD rows are left exactly as they are.
--   2. A column named `*_syp` is a Syrian-pound roll-up by definition and is
--      always converted.
--   3. A percentage, a score, a rate in basis points, a USD exposure and a
--      quantity are not money in lira and are never touched.
--
-- `fx_rate` moves with them: it is SYP per USD, so 13,000 becomes 130.
-- Ledger amounts and account balances are divided uniformly, which preserves
-- "debits equal credits" exactly — dividing both sides of an equality by the
-- same constant cannot unbalance it. Nothing is rounded here: the columns hold
-- four decimal places, so 12,345 old lira lands on 123.45 new rather than
-- being quietly rounded into a discrepancy.

-- ── Catalogue ────────────────────────────────────────────────────────────
UPDATE "products"
SET "min_price_syp" = "min_price_syp" / 100,
    "max_price_syp" = "max_price_syp" / 100;

UPDATE "seller_offers"
SET "price_syp" = "price_syp" / 100,
    "price" = CASE WHEN "currency" = 'SYP' THEN "price" / 100 ELSE "price" END,
    "compare_at_price" = CASE
      WHEN "currency" = 'SYP' THEN "compare_at_price" / 100
      ELSE "compare_at_price" END,
    "wholesale_price" = CASE
      WHEN "currency" = 'SYP' THEN "wholesale_price" / 100
      ELSE "wholesale_price" END;

-- Variant prices inherit their offer's currency.
UPDATE "seller_offer_variants" v
SET "price" = v."price" / 100
FROM "seller_offers" o
WHERE v."offer_id" = o."id" AND o."currency" = 'SYP';

-- ── Rates ────────────────────────────────────────────────────────────────
UPDATE "exchange_rates" SET "rate" = "rate" / 100 WHERE "quote" = 'SYP';
UPDATE "exchange_rates" SET "rate" = "rate" * 100 WHERE "base" = 'SYP';

-- ── Orders and their children ────────────────────────────────────────────
UPDATE "orders"
SET "items_subtotal" = "items_subtotal" / 100,
    "discount_total" = "discount_total" / 100,
    "shipping_total" = "shipping_total" / 100,
    "wallet_applied" = "wallet_applied" / 100,
    "points_applied" = "points_applied" / 100,
    "grand_total" = "grand_total" / 100,
    "fx_rate" = "fx_rate" / 100,
    -- Q48's "nearest thousand" is the nearest ten once two zeros are gone.
    "rounding_policy" = CASE
      WHEN "rounding_policy" = 'NEAREST_1000' THEN 'NEAREST_10'::"RoundingPolicy"
      ELSE "rounding_policy" END
WHERE "currency" = 'SYP';

UPDATE "seller_orders"
SET "items_subtotal" = "items_subtotal" / 100,
    "discount_total" = "discount_total" / 100,
    "shipping_cost" = "shipping_cost" / 100,
    "commission_base" = "commission_base" / 100,
    "commission_amount" = "commission_amount" / 100,
    "seller_net" = "seller_net" / 100
WHERE "currency" = 'SYP';

UPDATE "order_items"
SET "unit_price" = "unit_price" / 100,
    "unit_discount" = "unit_discount" / 100,
    "line_total" = "line_total" / 100
WHERE "currency" = 'SYP';

UPDATE "invoices"
SET "items_subtotal" = "items_subtotal" / 100,
    "discount_total" = "discount_total" / 100,
    "shipping_total" = "shipping_total" / 100,
    "grand_total" = "grand_total" / 100,
    "commission_amount" = "commission_amount" / 100,
    "seller_net" = "seller_net" / 100,
    "fx_rate" = "fx_rate" / 100
WHERE "currency" = 'SYP';

-- ── Money in and money out ───────────────────────────────────────────────
UPDATE "payments"
SET "amount" = "amount" / 100,
    "captured_amount" = "captured_amount" / 100,
    "refunded_amount" = "refunded_amount" / 100
WHERE "currency" = 'SYP';

UPDATE "payment_transactions" SET "amount" = "amount" / 100 WHERE "currency" = 'SYP';
UPDATE "return_requests" SET "refund_amount" = "refund_amount" / 100 WHERE "currency" = 'SYP';
UPDATE "disputes" SET "frozen_amount" = "frozen_amount" / 100 WHERE "currency" = 'SYP';

UPDATE "shipments"
SET "cod_amount" = "cod_amount" / 100,
    "collected_amount" = "collected_amount" / 100
WHERE "currency" = 'SYP';

UPDATE "cash_settlements"
SET "expected" = "expected" / 100,
    "collected" = "collected" / 100,
    "variance" = "variance" / 100
WHERE "currency" = 'SYP';

-- ── Fees, commissions, payouts ───────────────────────────────────────────
UPDATE "shipping_zones"
SET "base_fee" = "base_fee" / 100,
    "min_fee" = "min_fee" / 100,
    "max_fee" = "max_fee" / 100,
    "express_fee" = "express_fee" / 100
WHERE "currency" = 'SYP';

-- `discount_percent` is a percentage and stays as it is.
UPDATE "coupons"
SET "amount_off" = "amount_off" / 100,
    "min_order_amount" = "min_order_amount" / 100
WHERE "currency" = 'SYP';

UPDATE "coupon_redemptions" SET "amount" = "amount" / 100 WHERE "currency" = 'SYP';
UPDATE "referral_rewards" SET "cashback_amount" = "cashback_amount" / 100 WHERE "currency" = 'SYP';
UPDATE "loyalty_rewards" SET "cashback_amount" = "cashback_amount" / 100 WHERE "currency" = 'SYP';
UPDATE "cashback_ledger" SET "amount" = "amount" / 100 WHERE "currency" = 'SYP';
UPDATE "financial_ledger_entries" SET "amount" = "amount" / 100 WHERE "currency" = 'SYP';

UPDATE "commission_rules"
SET "fixed_fee" = "fixed_fee" / 100,
    "min_commission" = "min_commission" / 100,
    "max_commission" = "max_commission" / 100
WHERE "currency" = 'SYP';

UPDATE "commission_ledgers"
SET "gross" = "gross" / 100,
    "commission" = "commission" / 100,
    "platform_fee" = "platform_fee" / 100,
    "net" = "net" / 100
WHERE "currency" = 'SYP';

UPDATE "seller_payouts"
SET "gross" = "gross" / 100,
    "commission" = "commission" / 100,
    "platform_fees" = "platform_fees" / 100,
    "adjustments" = "adjustments" / 100,
    "net" = "net" / 100
WHERE "currency" = 'SYP';

-- ── The double-entry kernel and the wallets ──────────────────────────────
UPDATE "ledger_accounts" SET "balance" = "balance" / 100 WHERE "currency" = 'SYP';
UPDATE "journal_lines" SET "amount" = "amount" / 100 WHERE "currency" = 'SYP';
UPDATE "wallets" SET "balance" = "balance" / 100 WHERE "currency" = 'SYP';

UPDATE "wallet_transactions"
SET "amount" = "amount" / 100,
    "balance_after" = "balance_after" / 100
WHERE "currency" = 'SYP';

-- ── Everything else that is stated in lira ───────────────────────────────
UPDATE "commerce_contents" SET "revenue_generated" = "revenue_generated" / 100;
UPDATE "membership_accounts" SET "current_period_spend" = "current_period_spend" / 100;
UPDATE "wishlist_collection_items" SET "price_when_saved" = "price_when_saved" / 100;

UPDATE "user_style_preferences"
SET "budget_min_syp" = "budget_min_syp" / 100,
    "budget_max_syp" = "budget_max_syp" / 100,
    "typical_min_syp" = "typical_min_syp" / 100,
    "typical_max_syp" = "typical_max_syp" / 100;

UPDATE "ai_stylist_recommendations" SET "quoted_price_syp" = "quoted_price_syp" / 100;
UPDATE "ai_stylist_outfits" SET "total_syp" = "total_syp" / 100;
UPDATE "ai_stylist_outfit_items" SET "price_syp" = "price_syp" / 100;
UPDATE "visual_search_results" SET "quoted_price_syp" = "quoted_price_syp" / 100;

-- ── The trend engine's dated facts ───────────────────────────────────────
UPDATE "product_demand_daily"
SET "revenue_syp" = "revenue_syp" / 100,
    "min_price_syp" = "min_price_syp" / 100;
UPDATE "seller_demand_daily"
SET "revenue_syp" = "revenue_syp" / 100,
    "price_syp" = "price_syp" / 100;
UPDATE "category_demand_daily"
SET "revenue_syp" = "revenue_syp" / 100,
    "median_price_syp" = "median_price_syp" / 100;
UPDATE "trend_attribute_daily" SET "revenue_syp" = "revenue_syp" / 100;
UPDATE "trend_forecasts" SET "total_revenue_syp" = "total_revenue_syp" / 100;
