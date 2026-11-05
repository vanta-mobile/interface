class HistoryWindow {
  const HistoryWindow(this.start, this.end);
  factory HistoryWindow.recent(DateTime now, Duration duration) => HistoryWindow(
    now.millisecondsSinceEpoch - duration.inMilliseconds + 1,
    now.millisecondsSinceEpoch,
  );
  final int start, end;
  bool get valid => start >= 0 && end >= start && end <= 8640000000000000;
  bool get fitsRequest => valid && end - start < const Duration(days: 7).inMilliseconds;
  HistoryWindow get latestRequest {
    final earliest = end - const Duration(days: 7).inMilliseconds + 1;
    return HistoryWindow(start > earliest ? start : earliest, end);
  }

  List<HistoryWindow> split() {
    if (start == end) return const [];
    final middle = start + (end - start) ~/ 2;
    return [HistoryWindow(start, middle), HistoryWindow(middle + 1, end)];
  }

  @override
  bool operator ==(Object other) =>
      other is HistoryWindow && start == other.start && end == other.end;
  @override
  int get hashCode => Object.hash(start, end);
}
