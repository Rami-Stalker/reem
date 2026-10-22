-- Financial integrity guards.
--
-- `LedgerService` enforces the ledger's rules on the way in: every entry
-- balances, line amounts are positive, history is never edited. Those rules
-- held only for writes that went through it. A hand-run fix, a script, a
-- future service that writes `journal_lines` itself — any of them could leave
-- an entry that does not balance or rewrite one that already happened, and the
-- first anyone would hear of it was the nightly reconciliation. The database
-- now holds the same rules, so a write that breaks them fails where it is made.
--
-- Deliberate maintenance (a redenomination like 20260902170000, the demo seed
-- emptying its tables) opts out for one transaction with
--     SELECT set_config('reem.ledger_maintenance', 'on', true);
-- which is visible in the migration or script that does it.

-- ── 1. Purchase rewards are granted when a sale is final ─────────────────────
--
-- `PurchaseRewardsService` claims this column before granting an order's tier
-- spend, bonus points, cashback and referral reward. Every order that exists
-- today was already rewarded at checkout, so all of them are marked granted:
-- without this the first sweep would reward every past order a second time.
ALTER TABLE "orders" ADD COLUMN "rewards_granted_at" TIMESTAMP(3);
UPDATE "orders" SET "rewards_granted_at" = COALESCE("placed_at", "created_at");

-- ── 2. A journal line is for a positive amount ──────────────────────────────
ALTER TABLE "journal_lines"
  ADD CONSTRAINT "journal_lines_amount_positive" CHECK ("amount" > 0);

-- ── 3. Every journal entry balances, per currency, at commit ────────────────
--
-- Deferred to commit because an entry's lines are inserted one at a time; the
-- check runs once the whole entry is in place, and fails the transaction that
-- wrote it rather than leaving it for reconciliation to find.
CREATE OR REPLACE FUNCTION reem_assert_journal_entry_balanced()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  target uuid := COALESCE(NEW.entry_id, OLD.entry_id);
  off record;
  line_count integer;
BEGIN
  IF current_setting('reem.ledger_maintenance', true) = 'on' THEN
    RETURN NULL;
  END IF;

  SELECT count(*) INTO line_count FROM journal_lines WHERE entry_id = target;
  -- Every line of the entry is gone (the entry itself was removed): nothing
  -- is left to balance.
  IF line_count = 0 THEN
    RETURN NULL;
  END IF;

  FOR off IN
    SELECT currency,
           SUM(CASE WHEN direction = 'DEBIT' THEN amount ELSE -amount END) AS difference
      FROM journal_lines
     WHERE entry_id = target
     GROUP BY currency
    HAVING SUM(CASE WHEN direction = 'DEBIT' THEN amount ELSE -amount END) <> 0
  LOOP
    RAISE EXCEPTION
      'journal entry % does not balance in %: debits exceed credits by %',
      target, off.currency, off.difference
      USING ERRCODE = 'check_violation';
  END LOOP;

  RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER "journal_lines_entry_balanced"
  AFTER INSERT OR UPDATE OR DELETE ON "journal_lines"
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  EXECUTE FUNCTION reem_assert_journal_entry_balanced();

-- ── 4. The book of record is append-only ────────────────────────────────────
--
-- Corrections are reversals (`LedgerService.reverse`), never edits. The one
-- column a reversal sets on an existing entry is `reverses_id`, on the new
-- mirror entry, once; the foreign keys that point *out* of an entry (order,
-- sub-order, author) may still be nulled when what they point at is removed.
CREATE OR REPLACE FUNCTION reem_journal_append_only()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF current_setting('reem.ledger_maintenance', true) = 'on' THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION '% is append-only: post a reversal instead of deleting', TG_TABLE_NAME
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF TG_TABLE_NAME = 'journal_lines' THEN
    IF NEW.entry_id IS DISTINCT FROM OLD.entry_id
       OR NEW.account_id IS DISTINCT FROM OLD.account_id
       OR NEW.direction IS DISTINCT FROM OLD.direction
       OR NEW.amount IS DISTINCT FROM OLD.amount
       OR NEW.currency IS DISTINCT FROM OLD.currency THEN
      RAISE EXCEPTION 'journal_lines is append-only: post a reversal instead of editing a line'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
  ELSE
    IF NEW.type IS DISTINCT FROM OLD.type
       OR NEW.reference IS DISTINCT FROM OLD.reference
       OR NEW.occurred_at IS DISTINCT FROM OLD.occurred_at
       OR (OLD.reverses_id IS NOT NULL AND NEW.reverses_id IS DISTINCT FROM OLD.reverses_id) THEN
      RAISE EXCEPTION 'journal_entries is append-only: post a reversal instead of editing an entry'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER "journal_lines_append_only"
  BEFORE UPDATE OR DELETE ON "journal_lines"
  FOR EACH ROW
  EXECUTE FUNCTION reem_journal_append_only();

CREATE TRIGGER "journal_entries_append_only"
  BEFORE UPDATE OR DELETE ON "journal_entries"
  FOR EACH ROW
  EXECUTE FUNCTION reem_journal_append_only();

-- ── 5. A sale belongs to at most one payout ─────────────────────────────────
--
-- The link table was unique on (payout, sale) only, so two payouts created in
-- the same instant could both claim one sale and both be paid. A cancelled or
-- failed payout deletes its links, so at any moment a sale has at most one.
--
-- A trigger rather than a unique index: Prisma would have to model a unique
-- foreign key as a one-to-one relation, which changes the client's types for
-- every query that filters on a sale's payouts. The lock makes the check safe
-- against two inserts racing past it.
CREATE OR REPLACE FUNCTION reem_assert_sale_in_one_payout()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('payout-sale:' || NEW.ledger_id::text));
  IF EXISTS (
    SELECT 1 FROM seller_payout_ledgers
     WHERE ledger_id = NEW.ledger_id
       AND id IS DISTINCT FROM NEW.id
  ) THEN
    RAISE EXCEPTION 'commission ledger % already belongs to a payout', NEW.ledger_id
      USING ERRCODE = 'unique_violation';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER "seller_payout_ledgers_one_payout"
  BEFORE INSERT OR UPDATE OF "ledger_id" ON "seller_payout_ledgers"
  FOR EACH ROW
  EXECUTE FUNCTION reem_assert_sale_in_one_payout();
