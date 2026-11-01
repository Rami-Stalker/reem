-- Reactions on comments: ❤️ by default, or one of the reaction glyphs.
CREATE TABLE "commerce_content_comment_reactions" (
    "id" UUID NOT NULL,
    "comment_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "emoji" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "commerce_content_comment_reactions_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "commerce_content_comment_reactions_comment_id_user_id_key"
    ON "commerce_content_comment_reactions"("comment_id", "user_id");
CREATE INDEX "commerce_content_comment_reactions_user_id_comment_id_idx"
    ON "commerce_content_comment_reactions"("user_id", "comment_id");

ALTER TABLE "commerce_content_comment_reactions"
    ADD CONSTRAINT "commerce_content_comment_reactions_comment_id_fkey"
    FOREIGN KEY ("comment_id") REFERENCES "commerce_content_comments"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "commerce_content_comment_reactions"
    ADD CONSTRAINT "commerce_content_comment_reactions_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
