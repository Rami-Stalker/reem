-- One conversation between any two people.
--
-- ## What was wrong
--
-- `ChatsService.startConversation` looked a thread up by
-- `(type, buyer_id, seller_id, product_id, seller_order_id)`. A shopper who
-- asked a boutique about a dress, then about a scarf, then about the parcel
-- carrying both, finished with three separate conversations with the same
-- woman — the inbox showed that boutique three times, each row holding a
-- third of the history, each with its own unread count. Two taps on «راسلي
-- المتجر» before the first answered produced a fourth, because the read and
-- the write were not atomic and nothing in the schema said they had to be.
--
-- ## What this file does
--
-- Merges every existing duplicate into the oldest thread of each pair, then
-- makes the pair unique so the application can rely on it.
--
-- The merge order matters and is the reason this is not three statements:
--
--  1. Messages move first, because they are what a conversation *is*.
--  2. Participants are deduplicated by hand — `chat_participants` has its own
--     `(chat_id, user_id)` unique index, so moving a row whose user already
--     sits on the survivor would fail; those rows are folded (keeping the
--     furthest-along read cursor, so nothing a woman has already read comes
--     back unread) and then deleted.
--  3. Reports follow their chat.
--  4. The emptied duplicates are deleted last, once nothing references them.
--
-- `last_read_message_id` is deliberately not merged: it is a pointer into a
-- message list that has just changed underneath it, and `last_read_at` — a
-- timestamp, which every unread count in this codebase actually reads — is
-- both correct after the merge and the thing the counts use.
--
-- Rows with a null buyer or seller are left alone. Postgres treats NULLs as
-- distinct in a unique index, so they neither block the index nor get merged;
-- they are chats whose participant was deleted, which is unreachable history
-- rather than a live conversation.

-- The survivor for each pair: the oldest, so the answer is stable and the
-- history reads from its real beginning.
CREATE TEMP TABLE chat_merge_map AS
WITH ranked AS (
  SELECT
    id,
    buyer_id,
    seller_id,
    FIRST_VALUE(id) OVER (
      PARTITION BY buyer_id, seller_id
      ORDER BY created_at ASC, id ASC
    ) AS keep_id
  FROM chats
  WHERE buyer_id IS NOT NULL AND seller_id IS NOT NULL
)
SELECT id AS drop_id, keep_id
FROM ranked
WHERE id <> keep_id;

-- 1. The messages.
UPDATE messages m
SET chat_id = map.keep_id
FROM chat_merge_map map
WHERE m.chat_id = map.drop_id;

-- 2a. Fold a duplicate participation into the survivor's, keeping whichever
--     read cursor is further along.
UPDATE chat_participants keep
SET
  last_read_at = GREATEST(
    COALESCE(keep.last_read_at, TIMESTAMP '-infinity'),
    COALESCE(dup.last_read_at, TIMESTAMP '-infinity')
  ),
  muted_until = GREATEST(keep.muted_until, dup.muted_until),
  -- Archived only if she had archived *both*; otherwise the merged thread is
  -- live, which is the safe direction — a conversation reappearing in the
  -- inbox is recoverable, one that silently vanishes is not.
  archived_at = CASE
    WHEN keep.archived_at IS NULL OR dup.archived_at IS NULL THEN NULL
    ELSE LEAST(keep.archived_at, dup.archived_at)
  END
FROM chat_participants dup
JOIN chat_merge_map map ON map.drop_id = dup.chat_id
WHERE keep.chat_id = map.keep_id
  AND keep.user_id = dup.user_id;

-- 2b. Delete the folded rows, then move the ones with no counterpart.
DELETE FROM chat_participants dup
USING chat_merge_map map, chat_participants keep
WHERE dup.chat_id = map.drop_id
  AND keep.chat_id = map.keep_id
  AND keep.user_id = dup.user_id;

UPDATE chat_participants p
SET chat_id = map.keep_id
FROM chat_merge_map map
WHERE p.chat_id = map.drop_id;

-- 3. Reports follow their conversation.
UPDATE chat_reports r
SET chat_id = map.keep_id
FROM chat_merge_map map
WHERE r.chat_id = map.drop_id;

-- The survivor carries the most recent context and the latest activity, so the
-- merged thread's header names what they were last talking about rather than
-- what they were talking about first.
UPDATE chats keep
SET
  product_id = COALESCE(latest.product_id, keep.product_id),
  seller_order_id = COALESCE(latest.seller_order_id, keep.seller_order_id),
  title = COALESCE(latest.title, keep.title),
  updated_at = GREATEST(keep.updated_at, latest.updated_at)
FROM (
  SELECT DISTINCT ON (map.keep_id)
    map.keep_id,
    c.product_id,
    c.seller_order_id,
    c.title,
    c.updated_at
  FROM chat_merge_map map
  JOIN chats c ON c.id = map.drop_id
  ORDER BY map.keep_id, c.updated_at DESC, c.id
) AS latest
WHERE keep.id = latest.keep_id;

-- 4. The emptied duplicates.
DELETE FROM chats c
USING chat_merge_map map
WHERE c.id = map.drop_id;

DROP TABLE chat_merge_map;

-- The rule, now enforceable.
DROP INDEX IF EXISTS "chats_buyer_id_seller_id_idx";
CREATE UNIQUE INDEX "chats_buyer_id_seller_id_key"
  ON "chats" ("buyer_id", "seller_id");
