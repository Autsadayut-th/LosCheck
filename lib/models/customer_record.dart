class CustomerRecord {
  const CustomerRecord({
    required this.phone,
    required this.name,
    required this.address,
    required this.createdAt,
    this.imageUrl,
  });

  final String phone;
  final String name;
  final String address;
  final DateTime createdAt;
  final String? imageUrl;

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
    return json;
  }

  static CustomerRecord fromJson(Map<String, dynamic> json) {
    return CustomerRecord(
      phone: json['phone'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      imageUrl: json['imageUrl'] as String?,
    );
  }
}
