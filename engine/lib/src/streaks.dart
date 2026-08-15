/// Daily-streak arithmetic.
///
/// This lives in the engine, away from any UI, because calendar logic is easy
/// to get subtly wrong and miserable to debug through a widget tree. Month
/// ends, leap days and daylight saving all break the obvious implementations.
library;

/// A calendar day encoded as `yyyymmdd`, which sorts correctly and stores in a
/// single integer.
abstract final class DayKey {
  static int of(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;

  /// Rebuilds the day as a UTC instant.
  ///
  /// UTC on purpose: only calendar adjacency matters, and a local-time
  /// difference across a daylight-saving boundary is 23 or 25 hours, which
  /// makes `inDays` report 0 or 1 for the same pair of dates.
  static DateTime toDate(int key) =>
      DateTime.utc(key ~/ 10000, (key ~/ 100) % 100, key % 100);

  /// True when [later] is the very next calendar day after [earlier].
  static bool isNextDay(int earlier, int later) =>
      toDate(later).difference(toDate(earlier)).inDays == 1;

  /// Whole days between two keys, negative when [later] precedes [earlier].
  static int daysBetween(int earlier, int later) =>
      toDate(later).difference(toDate(earlier)).inDays;
}

/// A running daily streak.
class Streak {
  const Streak({this.current = 0, this.longest = 0, this.lastDay});

  /// Days in a row up to and including [lastDay].
  final int current;

  /// Best run ever recorded.
  final int longest;

  /// Day of the most recent completed daily, or null if there has never been
  /// one.
  final int? lastDay;

  /// The streak after finishing the daily puzzle for [day].
  ///
  /// Finishing the same day twice changes nothing, so replaying a daily cannot
  /// inflate a streak.
  Streak recordWin(DateTime day) {
    final key = DayKey.of(day);
    final previous = lastDay;

    if (previous == null) {
      return Streak(current: 1, longest: longest < 1 ? 1 : longest, lastDay: key);
    }
    if (previous == key) return this;
    // A win backdated before the last recorded day is ignored rather than
    // allowed to corrupt the run.
    if (DayKey.daysBetween(previous, key) < 0) return this;

    final next = DayKey.isNextDay(previous, key) ? current + 1 : 1;
    return Streak(
      current: next,
      longest: next > longest ? next : longest,
      lastDay: key,
    );
  }

  /// The streak as it stands on [today].
  ///
  /// A run only survives while it is current: if the last win was before
  /// yesterday it has already lapsed, and showing it as live would be a lie.
  /// Today's own streak is not broken until tomorrow arrives.
  int currentAsOf(DateTime today) {
    final previous = lastDay;
    if (previous == null) return 0;
    final gap = DayKey.daysBetween(previous, DayKey.of(today));
    return gap <= 1 ? current : 0;
  }

  /// True when the daily for [day] has already been finished.
  bool hasPlayed(DateTime day) => lastDay == DayKey.of(day);
}
