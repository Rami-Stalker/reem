-- The ranked feed: what has already been shown to each woman, so a refresh
-- brings something new and a boutique nobody has seen yet can be found.

-- CreateTable
CREATE TABLE "feed_seen" (
    "user_id" UUID NOT NULL,
    "content_id" UUID NOT NULL,
    "served_count" INTEGER NOT NULL DEFAULT 1,
    "last_served_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "feed_seen_pkey" PRIMARY KEY ("user_id","content_id")
);

-- CreateIndex
CREATE INDEX "feed_seen_user_id_last_served_at_idx" ON "feed_seen"("user_id", "last_served_at");

-- CreateIndex
CREATE INDEX "feed_seen_content_id_last_served_at_idx" ON "feed_seen"("content_id", "last_served_at");

-- CreateIndex
CREATE INDEX "feed_seen_last_served_at_idx" ON "feed_seen"("last_served_at");

-- AddForeignKey
ALTER TABLE "feed_seen" ADD CONSTRAINT "feed_seen_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "feed_seen" ADD CONSTRAINT "feed_seen_content_id_fkey" FOREIGN KEY ("content_id") REFERENCES "commerce_contents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

