-- Reem Rooms — telling the room.
--
-- One enum value and one preference column. Room activity is coalesced per room
-- rather than emitted per gesture (see `RoomNotifier`), so this adds no table:
-- a room's afternoon of votes is one notification row that keeps being rewritten
-- while it stays unread.
--
-- The preference defaults to true. Being invited into a room is asking to be
-- told what happens in it, and a room nobody hears about stops being a
-- conversation.

-- AlterEnum
ALTER TYPE "NotificationType" ADD VALUE 'room';

-- AlterTable
ALTER TABLE "notification_preferences" ADD COLUMN     "in_app_rooms" BOOLEAN NOT NULL DEFAULT true;
