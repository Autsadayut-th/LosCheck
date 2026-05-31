class TripRecord {
  const TripRecord({
    required this.distanceLabel,
    required this.rateBaht,
    required this.rounds,
    required this.createdAt,
    this.supabaseId,
  });

  final String distanceLabel;
  final int rateBaht;
  final int rounds;
  final DateTime createdAt;
  final int? supabaseId;

  int get totalBaht => rounds * rateBaht;

  bool isSameDay(DateTime date) {
    return createdAt.year == date.year &&
        createdAt.month == date.month &&
        createdAt.day == date.day;
  }

  Map<String, Object> toJson() {
    final json = <String, Object>{
      'distanceLabel': distanceLabel,
      'rateBaht': rateBaht,
      'rounds': rounds,
      'createdAt': createdAt.toIso8601String(),
    };
    if (supabaseId != null) {
      json['supabaseId'] = supabaseId!;
    }
    return json;
  }

  Map<String, Object> toSupabaseJson() {
    return {
      'distance_label': distanceLabel,
      'rate_baht': rateBaht,
      'rounds': rounds,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static TripRecord fromJson(Map<String, dynamic> json) {
    return TripRecord(
      distanceLabel: json['distanceLabel'] as String,
      rateBaht: json['rateBaht'] as int,
      rounds: json['rounds'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      supabaseId: json['supabaseId'] as int?,
    );
  }

  static TripRecord fromSupabaseJson(Map<String, dynamic> json) {
    return TripRecord(
      distanceLabel: json['distance_label'] as String,
      rateBaht: json['rate_baht'] as int,
      rounds: json['rounds'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      supabaseId: json['id'] as int?,
    );
  }
}
