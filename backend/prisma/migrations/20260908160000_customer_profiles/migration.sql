-- What the platform has worked out about each customer.
--
-- Four readings — how likely she is to buy, how likely she is to leave, what
-- she is worth, and when she is awake — cached so the jobs and rankings that
-- consume them do not each recompute over a hundred thousand events.
--
-- A cache and never a source of truth: every figure is derived from orders and
-- analytics events that stay exactly where they are, and the whole table can
-- be dropped and rebuilt from them. `computed_at` is stored rather than implied
-- so a screen can say how old a reading is instead of presenting yesterday's
-- as today's.
--
-- The scoring itself lives in `customer-intelligence/kernel`, deterministic and
-- explainable, and its central idea is that a customer is judged against *her
-- own* cadence rather than a fixed number of days. Sixty days of silence from
-- a woman who buys every three weeks and from one who buys twice a year are
-- opposite facts, and a fixed "lapsed at 90 days" rule — which is what almost
-- every marketplace ships — is wrong about one of them whichever number it
-- picks.
-- CreateTable
CREATE TABLE "customer_profiles" (
    "user_id" UUID NOT NULL,
    "propensity_score" DOUBLE PRECISION NOT NULL,
    "propensity_band" TEXT NOT NULL,
    "churn_score" DOUBLE PRECISION NOT NULL,
    "churn_band" TEXT NOT NULL,
    "cadence_days" DOUBLE PRECISION,
    "realised_value" DECIMAL(18,4) NOT NULL,
    "projected_value" DECIMAL(18,4) NOT NULL,
    "value_horizon_days" INTEGER NOT NULL,
    "currency" "Currency" NOT NULL DEFAULT 'SYP',
    "best_contact_hour" INTEGER,
    "signals" JSONB NOT NULL,
    "confident" BOOLEAN NOT NULL DEFAULT false,
    "computed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "customer_profiles_pkey" PRIMARY KEY ("user_id")
);

-- CreateIndex
CREATE INDEX "customer_profiles_churn_band_churn_score_idx" ON "customer_profiles"("churn_band", "churn_score");

-- CreateIndex
CREATE INDEX "customer_profiles_propensity_band_propensity_score_idx" ON "customer_profiles"("propensity_band", "propensity_score");

-- CreateIndex
CREATE INDEX "customer_profiles_computed_at_idx" ON "customer_profiles"("computed_at");

-- AddForeignKey
ALTER TABLE "customer_profiles" ADD CONSTRAINT "customer_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

