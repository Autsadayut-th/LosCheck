class CustomerRecord {
  const CustomerRecord({
    required this.phone,
    required this.name,
    required this.address,
    required this.createdAt,
    this.supabaseId,
  });

  final String phone;
  final String name;
  final String address;
  final DateTime createdAt;
  final int? supabaseId;

  Map<String, Object> toJson() {
    final json = <String, Object>{
      'phone': phone,
      'name': name,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
    };
    if (supabaseId != null) {
      json['supabaseId'] = supabaseId!;
    }
    return json;
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
      supabaseId: json['supabaseId'] as int?,
    );
  }

  static CustomerRecord fromSupabaseJson(Map<String, dynamic> json) {
    return CustomerRecord(
      phone: json['phone'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      supabaseId: json['id'] as int?,
    );
  }
}
