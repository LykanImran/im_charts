/// Supported chart timeframes.
enum Timeframe {
  oneMinute(Duration(minutes: 1), '1m', '1 min'),
  threeMinutes(Duration(minutes: 3), '3m', '3 min'),
  fiveMinutes(Duration(minutes: 5), '5m', '5 min'),
  fifteenMinutes(Duration(minutes: 15), '15m', '15 min'),
  thirtyMinutes(Duration(minutes: 30), '30m', '30 min'),
  oneHour(Duration(hours: 1), '1H', '1 hour'),
  oneDay(Duration(days: 1), '1D', '1 day'),
  oneWeek(Duration(days: 7), '1W', '1 week');

  final Duration duration;
  final String shortLabel;
  final String fullLabel;

  const Timeframe(this.duration, this.shortLabel, this.fullLabel);

  /// Aligns a given [dateTime] down to the nearest start boundary for this timeframe.
  DateTime alignTimestamp(DateTime dateTime) {
    if (this == oneDay) {
      return DateTime(dateTime.year, dateTime.month, dateTime.day);
    } else if (this == oneWeek) {
      final daysToSubtract = (dateTime.weekday - DateTime.monday) % 7;
      final monday = dateTime.subtract(Duration(days: daysToSubtract));
      return DateTime(monday.year, monday.month, monday.day);
    } else if (this == oneHour) {
      return DateTime(dateTime.year, dateTime.month, dateTime.day, dateTime.hour);
    } else {
      final totalMinutes = dateTime.minute;
      final roundedMinutes = (totalMinutes ~/ duration.inMinutes) * duration.inMinutes;
      return DateTime(
        dateTime.year,
        dateTime.month,
        dateTime.day,
        dateTime.hour,
        roundedMinutes,
      );
    }
  }
}
