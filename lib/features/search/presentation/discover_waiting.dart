import 'package:ohara/core/utils/damascus_time.dart';
import 'package:ohara/features/rooms/domain/entities/room.dart';

/// A room with a date coming up, and how many days are left until it.
typedef UpcomingRoom = ({Room room, int daysLeft});

/// The rooms Discover should open with: open, dated, not yet past, soonest
/// first, at most [limit] of them.
///
/// A room is a shopping intent with a deadline — «عرس سلمى» on Thursday — and
/// that is a better first answer to "what do I need" than any aisle. Only open
/// rooms count: a room she already bought from, or archived, is not waiting
/// for anything. Days are counted on the Damascus calendar, the same one the
/// greeting reads, so "tomorrow" means her tomorrow whatever the handset's
/// clock says.
List<UpcomingRoom> upcomingRooms(
  List<Room> rooms, {
  DateTime? clock,
  int limit = 2,
}) {
  final now = damascusNow(clock: clock);
  final today = DateTime.utc(now.year, now.month, now.day);

  final upcoming = <UpcomingRoom>[];
  for (final room in rooms) {
    final target = room.targetDate;
    if (target == null) continue;
    if (room.status == RoomStatus.purchased ||
        room.status == RoomStatus.archived) {
      continue;
    }
    final local = target.toUtc().add(damascusOffset);
    final day = DateTime.utc(local.year, local.month, local.day);
    final daysLeft = day.difference(today).inDays;
    if (daysLeft < 0) continue;
    upcoming.add((room: room, daysLeft: daysLeft));
  }

  upcoming.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
  return upcoming.take(limit).toList(growable: false);
}
