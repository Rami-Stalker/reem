-- AlterTable
ALTER TABLE "seller_reputations" ALTER COLUMN "response_score" DROP NOT NULL,
ALTER COLUMN "response_score" DROP DEFAULT;
