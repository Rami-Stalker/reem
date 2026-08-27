-- Guest-first identity, admin role separation, seller levels, and security event stream.

ALTER TYPE "UserRole" ADD VALUE IF NOT EXISTS 'OPERATIONS_ADMIN';
ALTER TYPE "UserRole" ADD VALUE IF NOT EXISTS 'SUPPORT_ADMIN';
ALTER TYPE "UserRole" ADD VALUE IF NOT EXISTS 'FINANCE_ADMIN';
ALTER TYPE "UserRole" ADD VALUE IF NOT EXISTS 'CONTENT_MODERATOR';

DO $$ BEGIN
    CREATE TYPE "SellerLevel" AS ENUM ('BASIC', 'VERIFIED', 'PREMIUM');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE "GuestSessionStatus" AS ENUM ('ACTIVE', 'MIGRATED', 'REVOKED', 'EXPIRED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE "GuestSavedItemType" AS ENUM ('PRODUCT', 'SELLER', 'POST');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE "SecurityEventType" AS ENUM (
        'GUEST_CREATED',
        'GUEST_MIGRATED',
        'LOGIN_SUCCESS',
        'LOGIN_FAILURE',
        'SUSPICIOUS_LOGIN',
        'REFRESH_TOKEN_REUSE',
        'SESSION_REVOKED',
        'DEVICE_CREATED',
        'DEVICE_TRUSTED',
        'DEVICE_REVOKED',
        'AUTHZ_DENIED',
        'PASSWORD_CHANGED',
        'SELLER_VERIFICATION_SUBMITTED',
        'SELLER_VERIFICATION_REVIEWED'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE "RiskLevel" AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "seller_level" "SellerLevel" NOT NULL DEFAULT 'BASIC';
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "seller_verified_at" TIMESTAMP(3);
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "seller_premium_until" TIMESTAMP(3);

CREATE TABLE IF NOT EXISTS "guest_sessions" (
    "id" UUID NOT NULL,
    "token_hash" TEXT NOT NULL,
    "status" "GuestSessionStatus" NOT NULL DEFAULT 'ACTIVE',
    "device_id" TEXT,
    "device_name" TEXT,
    "platform" TEXT,
    "app_version" TEXT,
    "fingerprint_hash" TEXT,
    "ip_address" TEXT,
    "user_agent" TEXT,
    "migrated_to_user_id" UUID,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "last_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "migrated_at" TIMESTAMP(3),
    "revoked_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "guest_sessions_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "guest_cart_items" (
    "id" UUID NOT NULL,
    "guest_session_id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "variant_id" UUID,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "guest_cart_items_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "guest_saved_items" (
    "id" UUID NOT NULL,
    "guest_session_id" UUID NOT NULL,
    "type" "GuestSavedItemType" NOT NULL,
    "product_id" UUID,
    "seller_id" UUID,
    "post_id" UUID,
    "metadata" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "guest_saved_items_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "security_events" (
    "id" UUID NOT NULL,
    "type" "SecurityEventType" NOT NULL,
    "risk_level" "RiskLevel" NOT NULL DEFAULT 'LOW',
    "actor_id" UUID,
    "guest_session_id" UUID,
    "session_id" UUID,
    "device_id" UUID,
    "ip_address" TEXT,
    "user_agent" TEXT,
    "resource" TEXT,
    "metadata" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "security_events_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "guest_sessions_token_hash_key" ON "guest_sessions"("token_hash");
CREATE INDEX IF NOT EXISTS "guest_sessions_status_expires_at_idx" ON "guest_sessions"("status", "expires_at");
CREATE INDEX IF NOT EXISTS "guest_sessions_fingerprint_hash_idx" ON "guest_sessions"("fingerprint_hash");
CREATE INDEX IF NOT EXISTS "guest_sessions_migrated_to_user_id_idx" ON "guest_sessions"("migrated_to_user_id");
CREATE INDEX IF NOT EXISTS "guest_cart_items_guest_session_id_idx" ON "guest_cart_items"("guest_session_id");
CREATE INDEX IF NOT EXISTS "guest_cart_items_product_id_idx" ON "guest_cart_items"("product_id");
CREATE INDEX IF NOT EXISTS "guest_saved_items_guest_session_id_created_at_idx" ON "guest_saved_items"("guest_session_id", "created_at");
CREATE INDEX IF NOT EXISTS "guest_saved_items_product_id_idx" ON "guest_saved_items"("product_id");
CREATE INDEX IF NOT EXISTS "guest_saved_items_seller_id_idx" ON "guest_saved_items"("seller_id");
CREATE INDEX IF NOT EXISTS "guest_saved_items_post_id_idx" ON "guest_saved_items"("post_id");
CREATE INDEX IF NOT EXISTS "security_events_actor_id_created_at_idx" ON "security_events"("actor_id", "created_at");
CREATE INDEX IF NOT EXISTS "security_events_guest_session_id_created_at_idx" ON "security_events"("guest_session_id", "created_at");
CREATE INDEX IF NOT EXISTS "security_events_type_created_at_idx" ON "security_events"("type", "created_at");
CREATE INDEX IF NOT EXISTS "security_events_risk_level_created_at_idx" ON "security_events"("risk_level", "created_at");

ALTER TABLE "guest_sessions" ADD CONSTRAINT "guest_sessions_migrated_to_user_id_fkey" FOREIGN KEY ("migrated_to_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "guest_cart_items" ADD CONSTRAINT "guest_cart_items_guest_session_id_fkey" FOREIGN KEY ("guest_session_id") REFERENCES "guest_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "guest_cart_items" ADD CONSTRAINT "guest_cart_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "guest_cart_items" ADD CONSTRAINT "guest_cart_items_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "product_variants"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "guest_saved_items" ADD CONSTRAINT "guest_saved_items_guest_session_id_fkey" FOREIGN KEY ("guest_session_id") REFERENCES "guest_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "guest_saved_items" ADD CONSTRAINT "guest_saved_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "guest_saved_items" ADD CONSTRAINT "guest_saved_items_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "guest_saved_items" ADD CONSTRAINT "guest_saved_items_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "security_events" ADD CONSTRAINT "security_events_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "security_events" ADD CONSTRAINT "security_events_guest_session_id_fkey" FOREIGN KEY ("guest_session_id") REFERENCES "guest_sessions"("id") ON DELETE SET NULL ON UPDATE CASCADE;
