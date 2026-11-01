-- «حذف لدي»: a message removed from one participant's view only. Kept on the
-- per-person receipt row, which already exists for every reader.
ALTER TABLE "message_read_receipts" ADD COLUMN "hidden_at" TIMESTAMP(3);
