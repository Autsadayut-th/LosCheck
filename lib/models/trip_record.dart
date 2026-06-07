class TripRecord {
  const TripRecord({
    required this.distanceLabel,
    required this.rateBaht,
    required this.rounds,
    required this.createdAt,
  });

  final String distanceLabel;
  final int rateBaht;
  final int rounds;
  final DateTime createdAt;

  int get totalBaht => rounds * rateBaht;

  bool isSameDay(DateTime date) {
    return createdAt.year == date.year &&
        createdAt.month == date.month &&
        createdAt.day == date.day;
  }

  Map<String, Object> toJson() {
    return {
      'distanceLabel': distanceLabel,
      'rateBaht': rateBaht,
      'rounds': rounds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static TripRecord fromJson(Map<String, dynamic> json) {
    return TripRecord(
      distanceLabel: json['distanceLabel'] as String,
      rateBaht: json['rateBaht'] as int,
      rounds: json['rounds'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
