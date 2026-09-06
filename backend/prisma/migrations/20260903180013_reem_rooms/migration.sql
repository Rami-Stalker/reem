-- ═══════════════════════════ Reem Rooms ═══════════════════════════
--
-- Nine tables and seven enums: deliberation before purchase.
--
-- Purely additive. `cart_items` is untouched and stays working — a room is for
-- a purchase worth thinking about, and a woman replacing a bottle of shampoo
-- should not have to open one. The two paths share one checkout; see the
-- section comment in schema.prisma.
--
-- No table here stores a price. Prices and stock move, and a plan that
-- remembered last week's total would show a figure that had quietly stopped
-- being true — so totals are computed on read and frozen exactly once, by
-- checkout, onto the order.

-- CreateEnum
CREATE TYPE "RoomKind" AS ENUM ('SOLO', 'GROUP', 'GIFT', 'OCCASION');

-- CreateEnum
CREATE TYPE "RoomStatus" AS ENUM ('PLANNING', 'DECIDING', 'READY', 'PURCHASED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "RoomMemberRole" AS ENUM ('OWNER', 'CO_SHOPPER', 'ADVISOR', 'VIEWER');

-- CreateEnum
CREATE TYPE "RoomMemberStatus" AS ENUM ('INVITED', 'ACTIVE', 'DECLINED', 'REMOVED');

-- CreateEnum
CREATE TYPE "RoomDecisionStatus" AS ENUM ('OPEN', 'RESOLVED', 'SKIPPED');

-- CreateEnum
CREATE TYPE "RoomCandidateStatus" AS ENUM ('CANDIDATE', 'SHORTLISTED', 'CHOSEN', 'REJECTED');

-- CreateEnum
CREATE TYPE "PurchasePlanStatus" AS ENUM ('DRAFT', 'CONFIRMED', 'ORDERED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "PurchaseStage" AS ENUM ('NOW', 'LATER');

-- CreateEnum
CREATE TYPE "RoomEventKind" AS ENUM ('ROOM_CREATED', 'MEMBER_JOINED', 'MEMBER_INVITED', 'DECISION_ADDED', 'CANDIDATE_ADDED', 'CANDIDATE_REMOVED', 'VOTE_CAST', 'COMMENT_ADDED', 'DECISION_RESOLVED', 'DECISION_SKIPPED', 'PLAN_DRAWN', 'PLAN_ORDERED');

-- CreateTable
CREATE TABLE "rooms" (
    "id" UUID NOT NULL,
    "owner_id" UUID NOT NULL,
    "kind" "RoomKind" NOT NULL DEFAULT 'SOLO',
    "status" "RoomStatus" NOT NULL DEFAULT 'PLANNING',
    "title" TEXT NOT NULL,
    "note" TEXT,
    "occasion" TEXT,
    "target_date" TIMESTAMP(3),
    "budget_min_syp" DECIMAL(18,4),
    "budget_max_syp" DECIMAL(18,4),
    "recipient_name" TEXT,
    "recipient_note" TEXT,
    "recipient_user_id" UUID,
    "is_surprise" BOOLEAN NOT NULL DEFAULT false,
    "cover_url" TEXT,
    "share_slug" TEXT,
    "share_role" "RoomMemberRole" NOT NULL DEFAULT 'ADVISOR',
    "decisions_count" INTEGER NOT NULL DEFAULT 0,
    "candidates_count" INTEGER NOT NULL DEFAULT 0,
    "members_count" INTEGER NOT NULL DEFAULT 1,
    "last_activity_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "rooms_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "room_members" (
    "id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "role" "RoomMemberRole" NOT NULL DEFAULT 'ADVISOR',
    "status" "RoomMemberStatus" NOT NULL DEFAULT 'ACTIVE',
    "invited_by_id" UUID,
    "display_name" TEXT,
    "joined_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_seen_at" TIMESTAMP(3),

    CONSTRAINT "room_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "room_decisions" (
    "id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "note" TEXT,
    "slot" "OutfitSlot",
    "status" "RoomDecisionStatus" NOT NULL DEFAULT 'OPEN',
    "pick_count" INTEGER NOT NULL DEFAULT 1,
    "position" INTEGER NOT NULL DEFAULT 0,
    "is_suggested" BOOLEAN NOT NULL DEFAULT false,
    "is_required" BOOLEAN NOT NULL DEFAULT true,
    "resolved_at" TIMESTAMP(3),
    "skipped_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "room_decisions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "room_candidates" (
    "id" UUID NOT NULL,
    "decision_id" UUID NOT NULL,
    "offer_id" UUID NOT NULL,
    "offer_variant_id" UUID,
    "product_id" UUID NOT NULL,
    "status" "RoomCandidateStatus" NOT NULL DEFAULT 'CANDIDATE',
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "position" INTEGER NOT NULL DEFAULT 0,
    "added_by_id" UUID,
    "note" TEXT,
    "rejection_note" TEXT,
    "vote_score" INTEGER NOT NULL DEFAULT 0,
    "votes_up" INTEGER NOT NULL DEFAULT 0,
    "votes_down" INTEGER NOT NULL DEFAULT 0,
    "chosen_at" TIMESTAMP(3),
    "rejected_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "room_candidates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "room_votes" (
    "id" UUID NOT NULL,
    "candidate_id" UUID NOT NULL,
    "member_id" UUID NOT NULL,
    "value" INTEGER NOT NULL,
    "note" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "room_votes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "room_comments" (
    "id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "member_id" UUID NOT NULL,
    "decision_id" UUID,
    "candidate_id" UUID,
    "body" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "room_comments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "room_events" (
    "id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "kind" "RoomEventKind" NOT NULL,
    "actor_id" UUID,
    "payload" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "room_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "purchase_plans" (
    "id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "buyer_id" UUID NOT NULL,
    "status" "PurchasePlanStatus" NOT NULL DEFAULT 'DRAFT',
    "version" INTEGER NOT NULL DEFAULT 1,
    "note" TEXT,
    "order_id" UUID,
    "confirmed_at" TIMESTAMP(3),
    "ordered_at" TIMESTAMP(3),
    "cancelled_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "purchase_plans_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "purchase_plan_items" (
    "id" UUID NOT NULL,
    "plan_id" UUID NOT NULL,
    "decision_id" UUID,
    "candidate_id" UUID,
    "offer_id" UUID NOT NULL,
    "offer_variant_id" UUID,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "stage" "PurchaseStage" NOT NULL DEFAULT 'NOW',
    "position" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "purchase_plan_items_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "rooms_share_slug_key" ON "rooms"("share_slug");

-- CreateIndex
CREATE INDEX "rooms_owner_id_status_last_activity_at_idx" ON "rooms"("owner_id", "status", "last_activity_at");

-- CreateIndex
CREATE INDEX "rooms_status_target_date_idx" ON "rooms"("status", "target_date");

-- CreateIndex
CREATE INDEX "room_members_room_id_status_idx" ON "room_members"("room_id", "status");

-- CreateIndex
CREATE INDEX "room_members_user_id_status_idx" ON "room_members"("user_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "room_members_room_id_user_id_key" ON "room_members"("room_id", "user_id");

-- CreateIndex
CREATE INDEX "room_decisions_room_id_status_position_idx" ON "room_decisions"("room_id", "status", "position");

-- CreateIndex
CREATE INDEX "room_candidates_decision_id_status_position_idx" ON "room_candidates"("decision_id", "status", "position");

-- CreateIndex
CREATE INDEX "room_candidates_product_id_idx" ON "room_candidates"("product_id");

-- CreateIndex
CREATE UNIQUE INDEX "room_candidates_decision_id_offer_id_offer_variant_id_key" ON "room_candidates"("decision_id", "offer_id", "offer_variant_id");

-- CreateIndex
CREATE INDEX "room_votes_member_id_idx" ON "room_votes"("member_id");

-- CreateIndex
CREATE UNIQUE INDEX "room_votes_candidate_id_member_id_key" ON "room_votes"("candidate_id", "member_id");

-- CreateIndex
CREATE INDEX "room_comments_room_id_created_at_idx" ON "room_comments"("room_id", "created_at");

-- CreateIndex
CREATE INDEX "room_comments_candidate_id_created_at_idx" ON "room_comments"("candidate_id", "created_at");

-- CreateIndex
CREATE INDEX "room_comments_decision_id_created_at_idx" ON "room_comments"("decision_id", "created_at");

-- CreateIndex
CREATE INDEX "room_events_room_id_created_at_idx" ON "room_events"("room_id", "created_at");

-- CreateIndex
CREATE INDEX "purchase_plans_room_id_status_idx" ON "purchase_plans"("room_id", "status");

-- CreateIndex
CREATE INDEX "purchase_plans_buyer_id_status_idx" ON "purchase_plans"("buyer_id", "status");

-- CreateIndex
CREATE INDEX "purchase_plan_items_plan_id_stage_position_idx" ON "purchase_plan_items"("plan_id", "stage", "position");

-- CreateIndex
CREATE UNIQUE INDEX "purchase_plan_items_plan_id_offer_id_offer_variant_id_key" ON "purchase_plan_items"("plan_id", "offer_id", "offer_variant_id");

-- AddForeignKey
ALTER TABLE "rooms" ADD CONSTRAINT "rooms_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rooms" ADD CONSTRAINT "rooms_recipient_user_id_fkey" FOREIGN KEY ("recipient_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_members" ADD CONSTRAINT "room_members_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_members" ADD CONSTRAINT "room_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_decisions" ADD CONSTRAINT "room_decisions_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_candidates" ADD CONSTRAINT "room_candidates_decision_id_fkey" FOREIGN KEY ("decision_id") REFERENCES "room_decisions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_candidates" ADD CONSTRAINT "room_candidates_offer_id_fkey" FOREIGN KEY ("offer_id") REFERENCES "seller_offers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_candidates" ADD CONSTRAINT "room_candidates_offer_variant_id_fkey" FOREIGN KEY ("offer_variant_id") REFERENCES "seller_offer_variants"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_candidates" ADD CONSTRAINT "room_candidates_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_candidates" ADD CONSTRAINT "room_candidates_added_by_id_fkey" FOREIGN KEY ("added_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_votes" ADD CONSTRAINT "room_votes_candidate_id_fkey" FOREIGN KEY ("candidate_id") REFERENCES "room_candidates"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_votes" ADD CONSTRAINT "room_votes_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "room_members"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_comments" ADD CONSTRAINT "room_comments_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_comments" ADD CONSTRAINT "room_comments_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "room_members"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_comments" ADD CONSTRAINT "room_comments_decision_id_fkey" FOREIGN KEY ("decision_id") REFERENCES "room_decisions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_comments" ADD CONSTRAINT "room_comments_candidate_id_fkey" FOREIGN KEY ("candidate_id") REFERENCES "room_candidates"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_events" ADD CONSTRAINT "room_events_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_events" ADD CONSTRAINT "room_events_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_plans" ADD CONSTRAINT "purchase_plans_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_plans" ADD CONSTRAINT "purchase_plans_buyer_id_fkey" FOREIGN KEY ("buyer_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_plans" ADD CONSTRAINT "purchase_plans_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_plan_items" ADD CONSTRAINT "purchase_plan_items_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "purchase_plans"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_plan_items" ADD CONSTRAINT "purchase_plan_items_decision_id_fkey" FOREIGN KEY ("decision_id") REFERENCES "room_decisions"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_plan_items" ADD CONSTRAINT "purchase_plan_items_candidate_id_fkey" FOREIGN KEY ("candidate_id") REFERENCES "room_candidates"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_plan_items" ADD CONSTRAINT "purchase_plan_items_offer_id_fkey" FOREIGN KEY ("offer_id") REFERENCES "seller_offers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_plan_items" ADD CONSTRAINT "purchase_plan_items_offer_variant_id_fkey" FOREIGN KEY ("offer_variant_id") REFERENCES "seller_offer_variants"("id") ON DELETE SET NULL ON UPDATE CASCADE;
