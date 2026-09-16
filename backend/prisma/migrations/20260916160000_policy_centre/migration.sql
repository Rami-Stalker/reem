-- The policy centre: eight documents the platform is answerable for, and the
-- record of who agreed to which issue of each.
--
-- Shape is document → version → translation, and the reason is evidentiary
-- rather than editorial. A consent is only worth something if the text it was
-- given against can still be produced, so a published version is frozen, an
-- edit is a new version, and an acceptance points at the version it was made
-- against — carrying the SHA-256 of the exact body that was on screen.
--
-- Purely additive. Nothing here touches an existing table except `users`,
-- which gains no column at all: the relation lives entirely on
-- `policy_acceptances`.
--
-- The rows themselves are not inserted here. `PolicyBootstrap` writes the
-- eight documents and their first published version on boot when the table is
-- empty, the same way `DeliveryProviderBootstrap` guarantees a carrier — which
-- keeps the Arabic and English bodies in reviewable TypeScript rather than in
-- a migration nobody will ever diff again.

-- CreateEnum
CREATE TYPE "PolicyDocumentKind" AS ENUM (
    'CUSTOMER_TERMS',
    'SELLER_TERMS',
    'PRIVACY',
    'RETURNS',
    'COMMISSIONS',
    'DISPUTES',
    'LIABILITY',
    'CONTENT'
);

-- CreateEnum
--
-- Who must *accept*, never who may read. Every published policy is public.
CREATE TYPE "PolicyAudience" AS ENUM ('EVERYONE', 'CUSTOMER', 'SELLER');

-- CreateEnum
CREATE TYPE "PolicyVersionStatus" AS ENUM ('DRAFT', 'PUBLISHED', 'ARCHIVED');

-- CreateTable
CREATE TABLE "policy_documents" (
    "id" UUID NOT NULL,
    "kind" "PolicyDocumentKind" NOT NULL,
    "slug" VARCHAR(64) NOT NULL,
    "audience" "PolicyAudience" NOT NULL DEFAULT 'EVERYONE',
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "required_for_consent" BOOLEAN NOT NULL DEFAULT false,
    "icon" VARCHAR(40),
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "policy_documents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "policy_document_versions" (
    "id" UUID NOT NULL,
    "document_id" UUID NOT NULL,
    "version" INTEGER NOT NULL,
    "status" "PolicyVersionStatus" NOT NULL DEFAULT 'DRAFT',
    "requires_reacceptance" BOOLEAN NOT NULL DEFAULT false,
    "effective_at" TIMESTAMP(3),
    "published_at" TIMESTAMP(3),
    "published_by_id" UUID,
    "change_note" VARCHAR(400),
    "created_by_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "policy_document_versions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "policy_document_translations" (
    "id" UUID NOT NULL,
    "version_id" UUID NOT NULL,
    "locale" VARCHAR(8) NOT NULL,
    "title" VARCHAR(200) NOT NULL,
    "summary" VARCHAR(400),
    "body" TEXT NOT NULL,
    "content_hash" VARCHAR(64) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "policy_document_translations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
--
-- Append-only by construction: no route updates or deletes one. The unique
-- key on (user, version) is what makes recording an acceptance idempotent —
-- a woman who taps «أوافق» twice on a flaky connection signs once.
CREATE TABLE "policy_acceptances" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "document_id" UUID NOT NULL,
    "version_id" UUID NOT NULL,
    "locale" VARCHAR(8) NOT NULL,
    "content_hash" VARCHAR(64) NOT NULL,
    "source" VARCHAR(40) NOT NULL,
    "accepted_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ip_address" VARCHAR(64),
    "user_agent" VARCHAR(400),

    CONSTRAINT "policy_acceptances_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "policy_documents_kind_key" ON "policy_documents"("kind");

-- CreateIndex
CREATE UNIQUE INDEX "policy_documents_slug_key" ON "policy_documents"("slug");

-- CreateIndex
CREATE INDEX "policy_documents_is_active_sort_order_idx" ON "policy_documents"("is_active", "sort_order");

-- CreateIndex
CREATE INDEX "policy_document_versions_document_id_status_idx" ON "policy_document_versions"("document_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "policy_document_versions_document_id_version_key" ON "policy_document_versions"("document_id", "version");

-- CreateIndex
CREATE UNIQUE INDEX "policy_document_translations_version_id_locale_key" ON "policy_document_translations"("version_id", "locale");

-- CreateIndex
CREATE INDEX "policy_acceptances_user_id_document_id_idx" ON "policy_acceptances"("user_id", "document_id");

-- CreateIndex
CREATE INDEX "policy_acceptances_version_id_idx" ON "policy_acceptances"("version_id");

-- CreateIndex
CREATE UNIQUE INDEX "policy_acceptances_user_id_version_id_key" ON "policy_acceptances"("user_id", "version_id");

-- AddForeignKey
ALTER TABLE "policy_document_versions" ADD CONSTRAINT "policy_document_versions_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "policy_documents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "policy_document_translations" ADD CONSTRAINT "policy_document_translations_version_id_fkey" FOREIGN KEY ("version_id") REFERENCES "policy_document_versions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "policy_acceptances" ADD CONSTRAINT "policy_acceptances_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "policy_acceptances" ADD CONSTRAINT "policy_acceptances_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "policy_documents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "policy_acceptances" ADD CONSTRAINT "policy_acceptances_version_id_fkey" FOREIGN KEY ("version_id") REFERENCES "policy_document_versions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- ── The permission that opens the console screen ──────────────────────────
--
-- `AppPermission.policyManage` is new, and `resolvePermissions` reads the RBAC
-- tables and only falls back to the code defaults when a role has *no* rows at
-- all. On an already-seeded database — which is every environment that matters
-- — the table wins, so a permission that exists only in TypeScript is a
-- permission nobody holds and a console screen that can only answer 403. The
-- seeder derives these tables from the code for a fresh database; this is the
-- same derivation for a database that already exists.
--
-- Idempotent, and it grants to exactly two roles: the owner and operations.
INSERT INTO "permissions" ("id", "key", "created_at")
VALUES (gen_random_uuid(), 'policy:manage', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;

INSERT INTO "role_permissions" ("id", "role_id", "permission_id")
SELECT gen_random_uuid(), r."id", p."id"
FROM "roles" r
CROSS JOIN "permissions" p
WHERE p."key" = 'policy:manage'
  AND r."name" IN ('SUPER_ADMIN', 'OPERATIONS_ADMIN')
ON CONFLICT ("role_id", "permission_id") DO NOTHING;
