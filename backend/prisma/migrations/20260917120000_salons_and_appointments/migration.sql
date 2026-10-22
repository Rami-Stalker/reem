-- الصالونات والجمال — salons, their services, their calendar, and the
-- appointments women book with them.
--
-- Purely additive. Six new tables, five new enums, one new value on
-- `NotificationType`, and one new relation each on `users` and `addresses`
-- that lives entirely on the new side. Nothing existing changes shape, and no
-- existing row is rewritten.
--
-- ## The invariant this file exists to make enforceable
--
-- A slot cannot be sold twice. That is not expressible as a unique index here:
-- services have different durations, so "the same slot" is an *overlap*
-- between two half-open intervals rather than an equal start time, and a
-- salon may serve several women at once. The rule is therefore enforced in
-- `AppointmentsService` under a `FOR UPDATE` lock on the salon row — the same
-- discipline `WalletService` and `CouponsService` use for their own
-- read-then-write races — and what this file contributes is the index that
-- makes the overlap query cheap enough to hold that lock for microseconds:
--
--   appointments (salon_id, starts_at, ends_at)
--
-- ## Why there is no money here
--
-- An appointment is a reservation. It is paid at the chair, so there is no
-- ledger entry, no escrow, no commission and no order row. `price` and
-- `currency` are frozen on the appointment purely so that a salon raising its
-- prices on Tuesday does not reprice Thursday's booking.

-- CreateEnum
CREATE TYPE "SalonStatus" AS ENUM ('DRAFT', 'ACTIVE', 'SUSPENDED');

-- CreateEnum
--
-- On the *service*, not the salon: a salon may do nails at home and colour
-- only in the chair.
CREATE TYPE "SalonServiceLocation" AS ENUM ('IN_SALON', 'AT_HOME', 'BOTH');

-- CreateEnum
--
-- Closed, because «تصفية حسب نوع الخدمة» is only answerable when two salons
-- spell "manicure" the same way.
CREATE TYPE "SalonServiceCategory" AS ENUM (
    'HAIR',
    'NAILS',
    'SKIN',
    'MAKEUP',
    'LASHES_BROWS',
    'HAIR_REMOVAL',
    'MASSAGE_SPA',
    'BRIDAL',
    'OTHER'
);

-- CreateEnum
CREATE TYPE "AppointmentStatus" AS ENUM (
    'PENDING',
    'CONFIRMED',
    'COMPLETED',
    'CANCELLED',
    'NO_SHOW'
);

-- CreateEnum
CREATE TYPE "AppointmentActor" AS ENUM ('CUSTOMER', 'SALON', 'SYSTEM');

-- AlterEnum
--
-- Additive. Postgres appends the value; every existing row keeps the type it
-- had, and the client falls back to its own default channel for a type it does
-- not recognise, so an older install is unaffected.
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'appointment';

-- CreateTable
CREATE TABLE "salons" (
    "id" UUID NOT NULL,
    "owner_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "tagline" TEXT,
    "about" TEXT,
    "status" "SalonStatus" NOT NULL DEFAULT 'DRAFT',
    "governorate" TEXT NOT NULL,
    "city" TEXT NOT NULL,
    "district" TEXT,
    "address_line" TEXT NOT NULL,
    "landmark" TEXT,
    -- The first coordinates on this platform. Nullable: a salon that has not
    -- dropped a pin is still a salon, and the page falls back to opening the
    -- written address in a maps app.
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "phone" TEXT,
    "whatsapp" TEXT,
    "logo_url" TEXT,
    "cover_url" TEXT,
    "slot_minutes" INTEGER NOT NULL DEFAULT 30,
    "lead_minutes" INTEGER NOT NULL DEFAULT 120,
    "horizon_days" INTEGER NOT NULL DEFAULT 30,
    "concurrent_capacity" INTEGER NOT NULL DEFAULT 1,
    "cancellation_hours" INTEGER NOT NULL DEFAULT 4,
    "home_service" BOOLEAN NOT NULL DEFAULT false,
    "home_service_fee" DECIMAL(18,4),
    "currency" "Currency" NOT NULL DEFAULT 'SYP',
    "rating" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "reviews_count" INTEGER NOT NULL DEFAULT 0,
    "appointments_count" INTEGER NOT NULL DEFAULT 0,
    "services_count" INTEGER NOT NULL DEFAULT 0,
    "is_featured" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "salons_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "salon_media" (
    "id" UUID NOT NULL,
    "salon_id" UUID NOT NULL,
    "url" TEXT NOT NULL,
    "type" "MediaType" NOT NULL DEFAULT 'image',
    "blur_hash" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "salon_media_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "salon_services" (
    "id" UUID NOT NULL,
    "salon_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "category" "SalonServiceCategory" NOT NULL DEFAULT 'OTHER',
    "price" DECIMAL(18,4) NOT NULL,
    "currency" "Currency" NOT NULL DEFAULT 'SYP',
    "compare_at_price" DECIMAL(18,4),
    -- Normalised, for the same reason `seller_offers.price_syp` is: ordering a
    -- mixed-currency directory by the raw column compares dollars to pounds.
    "price_syp" DECIMAL(18,4),
    "duration_minutes" INTEGER NOT NULL,
    "buffer_minutes" INTEGER NOT NULL DEFAULT 0,
    "location" "SalonServiceLocation" NOT NULL DEFAULT 'IN_SALON',
    "image_url" TEXT,
    "is_package" BOOLEAN NOT NULL DEFAULT false,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "salon_services_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "salon_package_items" (
    "id" UUID NOT NULL,
    "package_id" UUID NOT NULL,
    "service_id" UUID NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "salon_package_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
--
-- `HH:mm` strings, not instants: "we open at nine" is a fact about the clock on
-- the wall. The availability service composes them with a date.
CREATE TABLE "salon_working_hours" (
    "id" UUID NOT NULL,
    "salon_id" UUID NOT NULL,
    "weekday" INTEGER NOT NULL,
    "is_closed" BOOLEAN NOT NULL DEFAULT false,
    "opens_at" VARCHAR(5) NOT NULL,
    "closes_at" VARCHAR(5) NOT NULL,
    "break_starts_at" VARCHAR(5),
    "break_ends_at" VARCHAR(5),

    CONSTRAINT "salon_working_hours_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "salon_closures" (
    "id" UUID NOT NULL,
    "salon_id" UUID NOT NULL,
    "date" DATE NOT NULL,
    "reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "salon_closures_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "appointments" (
    "id" UUID NOT NULL,
    "reference" VARCHAR(16) NOT NULL,
    "salon_id" UUID NOT NULL,
    "customer_id" UUID NOT NULL,
    "service_id" UUID NOT NULL,
    "status" "AppointmentStatus" NOT NULL DEFAULT 'PENDING',
    -- Half-open [starts_at, ends_at), buffer included. Every overlap question
    -- is asked of these two columns and nothing else.
    "starts_at" TIMESTAMP(3) NOT NULL,
    "ends_at" TIMESTAMP(3) NOT NULL,
    -- Frozen at booking, so a price rise on Tuesday does not reprice Thursday.
    "service_name" TEXT NOT NULL,
    "duration_minutes" INTEGER NOT NULL,
    "price" DECIMAL(18,4) NOT NULL,
    "currency" "Currency" NOT NULL DEFAULT 'SYP',
    "at_home" BOOLEAN NOT NULL DEFAULT false,
    "address_id" UUID,
    "customer_note" TEXT,
    "salon_note" TEXT,
    "confirmed_at" TIMESTAMP(3),
    "completed_at" TIMESTAMP(3),
    "cancelled_at" TIMESTAMP(3),
    "cancelled_by" "AppointmentActor",
    "cancellation_reason" TEXT,
    "cancelled_late" BOOLEAN NOT NULL DEFAULT false,
    -- Stamped by the reminder job so it is idempotent across the catch-up runs
    -- a sleeping Free instance performs on waking.
    "reminder_sent_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "appointments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "salon_reviews" (
    "id" UUID NOT NULL,
    "appointment_id" UUID NOT NULL,
    "salon_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "rating" INTEGER NOT NULL,
    "body" TEXT,
    "status" "ReviewStatus" NOT NULL DEFAULT 'APPROVED',
    "salon_reply" TEXT,
    "salon_replied_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "salon_reviews_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "salons_slug_key" ON "salons"("slug");

-- CreateIndex
CREATE INDEX "salons_status_governorate_city_idx" ON "salons"("status", "governorate", "city");

-- CreateIndex
CREATE INDEX "salons_status_rating_idx" ON "salons"("status", "rating");

-- CreateIndex
CREATE INDEX "salons_owner_id_idx" ON "salons"("owner_id");

-- CreateIndex
CREATE INDEX "salon_media_salon_id_sort_order_idx" ON "salon_media"("salon_id", "sort_order");

-- CreateIndex
CREATE INDEX "salon_services_salon_id_is_active_sort_order_idx" ON "salon_services"("salon_id", "is_active", "sort_order");

-- CreateIndex
CREATE INDEX "salon_services_category_is_active_idx" ON "salon_services"("category", "is_active");

-- CreateIndex
CREATE INDEX "salon_services_is_active_price_syp_idx" ON "salon_services"("is_active", "price_syp");

-- CreateIndex
CREATE UNIQUE INDEX "salon_package_items_package_id_service_id_key" ON "salon_package_items"("package_id", "service_id");

-- CreateIndex
CREATE INDEX "salon_package_items_service_id_idx" ON "salon_package_items"("service_id");

-- CreateIndex
CREATE UNIQUE INDEX "salon_working_hours_salon_id_weekday_key" ON "salon_working_hours"("salon_id", "weekday");

-- CreateIndex
CREATE UNIQUE INDEX "salon_closures_salon_id_date_key" ON "salon_closures"("salon_id", "date");

-- CreateIndex
CREATE UNIQUE INDEX "appointments_reference_key" ON "appointments"("reference");

-- CreateIndex
--
-- The one the booking lock depends on. The overlap predicate is
-- `salon_id = $1 AND starts_at < $end AND ends_at > $start`, so this index is
-- what keeps the `FOR UPDATE` window short.
CREATE INDEX "appointments_salon_id_starts_at_ends_at_idx" ON "appointments"("salon_id", "starts_at", "ends_at");

-- CreateIndex
CREATE INDEX "appointments_customer_id_starts_at_idx" ON "appointments"("customer_id", "starts_at" DESC);

-- CreateIndex
CREATE INDEX "appointments_status_starts_at_idx" ON "appointments"("status", "starts_at");

-- CreateIndex
CREATE INDEX "appointments_service_id_idx" ON "appointments"("service_id");

-- CreateIndex
CREATE INDEX "appointments_address_id_idx" ON "appointments"("address_id");

-- CreateIndex
CREATE UNIQUE INDEX "salon_reviews_appointment_id_key" ON "salon_reviews"("appointment_id");

-- CreateIndex
CREATE INDEX "salon_reviews_salon_id_status_created_at_idx" ON "salon_reviews"("salon_id", "status", "created_at" DESC);

-- CreateIndex
CREATE INDEX "salon_reviews_user_id_idx" ON "salon_reviews"("user_id");

-- AddForeignKey
ALTER TABLE "salons" ADD CONSTRAINT "salons_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "salon_media" ADD CONSTRAINT "salon_media_salon_id_fkey" FOREIGN KEY ("salon_id") REFERENCES "salons"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "salon_services" ADD CONSTRAINT "salon_services_salon_id_fkey" FOREIGN KEY ("salon_id") REFERENCES "salons"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "salon_package_items" ADD CONSTRAINT "salon_package_items_package_id_fkey" FOREIGN KEY ("package_id") REFERENCES "salon_services"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "salon_package_items" ADD CONSTRAINT "salon_package_items_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "salon_services"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "salon_working_hours" ADD CONSTRAINT "salon_working_hours_salon_id_fkey" FOREIGN KEY ("salon_id") REFERENCES "salons"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "salon_closures" ADD CONSTRAINT "salon_closures_salon_id_fkey" FOREIGN KEY ("salon_id") REFERENCES "salons"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_salon_id_fkey" FOREIGN KEY ("salon_id") REFERENCES "salons"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
--
-- `RESTRICT`, deliberately: a service with appointments against it cannot be
-- deleted out from under them. The owner deactivates it instead, which takes
-- it off the menu and leaves every booking intact.
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "salon_services"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
--
-- `SET NULL`: deleting an address must not delete a booking she still has.
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_address_id_fkey" FOREIGN KEY ("address_id") REFERENCES "addresses"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "salon_reviews" ADD CONSTRAINT "salon_reviews_appointment_id_fkey" FOREIGN KEY ("appointment_id") REFERENCES "appointments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "salon_reviews" ADD CONSTRAINT "salon_reviews_salon_id_fkey" FOREIGN KEY ("salon_id") REFERENCES "salons"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "salon_reviews" ADD CONSTRAINT "salon_reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
