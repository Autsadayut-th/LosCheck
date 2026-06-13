import 'package:isar/isar.dart';
import 'customer_record.dart';

part 'isar_customer.g.dart';

@collection
class IsarCustomer {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String phone;

  late String name;
  late String address;
  String? imageUrl;
  late DateTime createdAt;

  // Convert to the existing CustomerRecord model
  CustomerRecord toCustomerRecord() {
    return CustomerRecord(
      phone: phone,
      name: name,
      address: address,
      createdAt: createdAt,
      imageUrl: imageUrl,
    );
  }

  // Create from the existing CustomerRecord model
  static IsarCustomer fromCustomerRecord(CustomerRecord record) {
    return IsarCustomer()
      ..phone = record.phone
      ..name = record.name
      ..address = record.address
      ..createdAt = record.createdAt
      ..imageUrl = record.imageUrl;
  }
}
