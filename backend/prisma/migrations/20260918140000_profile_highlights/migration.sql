-- «الأبرز» — the stories a woman keeps on her page past their day.
--
-- Purely additive: two new tables, one new relation each on `users` and
-- `commerce_contents` that lives entirely on the new side. Nothing existing
-- changes shape and no existing row is rewritten.
--
-- A highlight points at content rather than copying it, which is the decision
-- the foreign keys encode. `ON DELETE CASCADE` from `commerce_contents` is
-- deliberate: a story taken down by moderation, or deleted by its author,
-- leaves every highlight that carried it — a highlight is a shelf, not a
-- reprint, and a takedown that a shelf could survive would be no takedown.

CREATE TABLE "profile_highlights" (
    "id" UUID NOT NULL,
    "owner_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "cover_url" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "profile_highlights_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "profile_highlight_items" (
    "id" UUID NOT NULL,
    "highlight_id" UUID NOT NULL,
    "content_id" UUID NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "added_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "profile_highlight_items_pkey" PRIMARY KEY ("id")
);

-- The rail, in one index-only read.
CREATE INDEX "profile_highlights_owner_id_sort_order_created_at_idx"
    ON "profile_highlights" ("owner_id", "sort_order", "created_at");

CREATE INDEX "profile_highlight_items_highlight_id_sort_order_added_at_idx"
    ON "profile_highlight_items" ("highlight_id", "sort_order", "added_at");

CREATE INDEX "profile_highlight_items_content_id_idx"
    ON "profile_highlight_items" ("content_id");

-- One story cannot sit twice in one highlight. Adding it again updates its
-- position instead of making a second copy.
CREATE UNIQUE INDEX "profile_highlight_items_highlight_id_content_id_key"
    ON "profile_highlight_items" ("highlight_id", "content_id");

ALTER TABLE "profile_highlights"
    ADD CONSTRAINT "profile_highlights_owner_id_fkey"
    FOREIGN KEY ("owner_id") REFERENCES "users" ("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "profile_highlight_items"
    ADD CONSTRAINT "profile_highlight_items_highlight_id_fkey"
    FOREIGN KEY ("highlight_id") REFERENCES "profile_highlights" ("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "profile_highlight_items"
    ADD CONSTRAINT "profile_highlight_items_content_id_fkey"
    FOREIGN KEY ("content_id") REFERENCES "commerce_contents" ("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
