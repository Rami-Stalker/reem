-- The rounding step the new lira needs.
--
-- Postgres will not let a value be added to an enum and used by the same
-- transaction, and Prisma runs each migration in one — so the value arrives
-- here, on its own, and the redenomination that follows can use it.

ALTER TYPE "RoundingPolicy" ADD VALUE IF NOT EXISTS 'NEAREST_10' BEFORE 'NEAREST_100';
