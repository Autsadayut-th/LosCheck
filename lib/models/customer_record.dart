class CustomerRecord {
  const CustomerRecord({
    required this.phone,
    required this.name,
    required this.address,
    required this.createdAt,
    this.imageUrl,
    this.latitude,
    this.longitude,
  });

  final String phone;
  final String name;
  final String address;
  final DateTime createdAt;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;

  Map<String, Object> toJson() {
    final json = <String, Object>{
      'phone': phone,
      'name': name,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
    };
    if (imageUrl != null) {
      json['imageUrl'] = imageUrl!;
    }
    if (latitude != null) {
      json['latitude'] = latitude!;
    }
    if (longitude != null) {
      json['longitude'] = longitude!;
    }
    return json;
  }

  static CustomerRecord fromJson(Map<String, dynamic> json) {
    return CustomerRecord(
      phone: json['phone'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      imageUrl: json['imageUrl'] as String?,
      latitude: json['latitude'] is num ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] is num ? (json['longitude'] as num).toDouble() : null,
    );
  }
}
