/// What the notification engine has been doing, as three cross-tabs.
///
/// The endpoint answers `{unread_in_app, deliveries[], campaigns[], events[]}`,
/// where a row is a count against one or two axes. There is no id and no name
/// anywhere in it, which is why it cannot travel through the console's record
/// mapper: that mapper needs a row to be a *thing*, and these are tallies.
class NotificationCount {
  const NotificationCount({
    required this.count,
    this.channel = '',
    this.status = '',
    this.event = '',
  });

  final String channel;
  final String status;
  final String event;
  final int count;
}

class NotificationAnalytics {
  const NotificationAnalytics({
    required this.unreadInApp,
    required this.deliveries,
    required this.campaigns,
    required this.events,
  });

  final int unreadInApp;
  final List<NotificationCount> deliveries;
  final List<NotificationCount> campaigns;
  final List<NotificationCount> events;

  /// Sent and failed are summed off the event table rather than asked for
  /// separately, so the headline and the breakdown beneath it can never
  /// disagree with each other.
  int get sent => _eventTotal('sent');
  int get failed => _eventTotal('failed');

  int _eventTotal(String name) => events
      .where((row) => row.event.toLowerCase() == name)
      .fold(0, (total, row) => total + row.count);

  static NotificationAnalytics fromJson(Map<String, dynamic> json) {
    return NotificationAnalytics(
      unreadInApp: _int(json['unread_in_app']),
      deliveries: _rows(json['deliveries']),
      campaigns: _rows(json['campaigns']),
      events: _rows(json['events']),
    );
  }
}

List<NotificationCount> _rows(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((entry) {
    final row = Map<String, dynamic>.from(entry);
    return NotificationCount(
      channel: '${row['channel'] ?? ''}',
      status: '${row['status'] ?? ''}',
      event: '${row['event'] ?? ''}',
      count: _int(row['count']),
    );
  }).toList();
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}
