class CustomerRecord {
  const CustomerRecord({
    required this.phone,
    required this.name,
    required this.address,
    required this.createdAt,
  });

  final String phone;
  final String name;
  final String address;
  final DateTime createdAt;

  Map<String, Object> toJson() {
    return {
      'phone': phone,
      'name': name,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, Object> toSupabaseJson() {
    return {
      'phone': phone,
      'name': name,
      'address': address,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static CustomerRecord fromJson(Map<String, dynamic> json) {
    return CustomerRecord(
      phone: json['phone'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
