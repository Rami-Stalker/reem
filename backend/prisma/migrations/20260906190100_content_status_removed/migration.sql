-- `REMOVED` — a moderator took it down, as distinct from `DELETED`, which is
-- the author changing her mind. Only one of the two is reachable by her.
--
-- This migration does exactly one thing, and that is not tidiness. Postgres
-- will not let a newly added enum value be *used* in the transaction that adds
-- it, and Prisma wraps each migration in a transaction — so a migration that
-- both adds `REMOVED` and writes it fails at runtime with an error that reads
-- like a typo. Keeping it alone makes that impossible.
ALTER TYPE "CommerceContentStatus" ADD VALUE IF NOT EXISTS 'REMOVED';
