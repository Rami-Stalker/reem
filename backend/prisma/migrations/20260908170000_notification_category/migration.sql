-- Telling the messages she is waiting for from the ones the platform wants.
--
-- Frequency capping is impossible without this distinction, and getting it
-- wrong is worse than not capping: a cap that cannot tell an order update from
-- an offer either throttles the notification she has been refreshing the app
-- for, or fails to throttle the third promotion this week. Both lose her.
--
-- Existing rows default to TRANSACTIONAL, which is what nearly all of them
-- are — order status, payments, returns. Marketing is set explicitly at the
-- one place it originates.
-- CreateEnum
CREATE TYPE "NotificationCategory" AS ENUM ('TRANSACTIONAL', 'MARKETING');

-- AlterTable
ALTER TABLE "notification_deliveries" ADD COLUMN     "category" "NotificationCategory" NOT NULL DEFAULT 'TRANSACTIONAL';

