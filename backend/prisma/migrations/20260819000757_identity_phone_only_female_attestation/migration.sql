/*
  Warnings:

  - You are about to drop the `linked_accounts` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropForeignKey
ALTER TABLE "linked_accounts" DROP CONSTRAINT "linked_accounts_user_id_fkey";

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "declared_female_at" TIMESTAMP(3);

-- DropTable
DROP TABLE "linked_accounts";

-- DropEnum
DROP TYPE "AuthProvider";
