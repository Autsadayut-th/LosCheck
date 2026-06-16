class RouteCompletionRecord {
  const RouteCompletionRecord({
    required this.points,
    required this.distance,
    required this.createdAt,
    this.id,
  });

  /// Database primary key. Null for records that have not been inserted yet.
  final int? id;
  final int points;
  final double distance;
  final DateTime createdAt;

  bool isSameDay(DateTime date) {
    return createdAt.year == date.year &&
        createdAt.month == date.month &&
        createdAt.day == date.day;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteCompletionRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          points == other.points &&
          distance == other.distance &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, points, distance, createdAt);

  Map<String, Object> toJson() {
    return {
      'points': points,
      'distance': distance,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static RouteCompletionRecord fromJson(Map<String, dynamic> json, {int? id}) {
    return RouteCompletionRecord(
      id: id,
      points: json['points'] as int,
      distance: (json['distance'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
