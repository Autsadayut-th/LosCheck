// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CustomerRecordsTable extends CustomerRecords
    with TableInfo<$CustomerRecordsTable, CustomerRecordData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomerRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [phone, name, address, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'customer_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomerRecordData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {phone};
  @override
  CustomerRecordData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomerRecordData(
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CustomerRecordsTable createAlias(String alias) {
    return $CustomerRecordsTable(attachedDatabase, alias);
  }
}

class CustomerRecordData extends DataClass
    implements Insertable<CustomerRecordData> {
  final String phone;
  final String name;
  final String address;
  final DateTime createdAt;
  const CustomerRecordData({
    required this.phone,
    required this.name,
    required this.address,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['phone'] = Variable<String>(phone);
    map['name'] = Variable<String>(name);
    map['address'] = Variable<String>(address);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CustomerRecordsCompanion toCompanion(bool nullToAbsent) {
    return CustomerRecordsCompanion(
      phone: Value(phone),
      name: Value(name),
      address: Value(address),
      createdAt: Value(createdAt),
    );
  }

  factory CustomerRecordData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomerRecordData(
      phone: serializer.fromJson<String>(json['phone']),
      name: serializer.fromJson<String>(json['name']),
      address: serializer.fromJson<String>(json['address']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'phone': serializer.toJson<String>(phone),
      'name': serializer.toJson<String>(name),
      'address': serializer.toJson<String>(address),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CustomerRecordData copyWith({
    String? phone,
    String? name,
    String? address,
    DateTime? createdAt,
  }) => CustomerRecordData(
    phone: phone ?? this.phone,
    name: name ?? this.name,
    address: address ?? this.address,
    createdAt: createdAt ?? this.createdAt,
  );
  CustomerRecordData copyWithCompanion(CustomerRecordsCompanion data) {
    return CustomerRecordData(
      phone: data.phone.present ? data.phone.value : this.phone,
      name: data.name.present ? data.name.value : this.name,
      address: data.address.present ? data.address.value : this.address,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomerRecordData(')
          ..write('phone: $phone, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(phone, name, address, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomerRecordData &&
          other.phone == this.phone &&
          other.name == this.name &&
          other.address == this.address &&
          other.createdAt == this.createdAt);
}

class CustomerRecordsCompanion extends UpdateCompanion<CustomerRecordData> {
  final Value<String> phone;
  final Value<String> name;
  final Value<String> address;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CustomerRecordsCompanion({
    this.phone = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomerRecordsCompanion.insert({
    required String phone,
    required String name,
    required String address,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : phone = Value(phone),
       name = Value(name),
       address = Value(address),
       createdAt = Value(createdAt);
  static Insertable<CustomerRecordData> custom({
    Expression<String>? phone,
    Expression<String>? name,
    Expression<String>? address,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (phone != null) 'phone': phone,
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomerRecordsCompanion copyWith({
    Value<String>? phone,
    Value<String>? name,
    Value<String>? address,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CustomerRecordsCompanion(
      phone: phone ?? this.phone,
      name: name ?? this.name,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomerRecordsCompanion(')
          ..write('phone: $phone, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TripRecordsTable extends TripRecords
    with TableInfo<$TripRecordsTable, TripRecordData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _distanceLabelMeta = const VerificationMeta(
    'distanceLabel',
  );
  @override
  late final GeneratedColumn<String> distanceLabel = GeneratedColumn<String>(
    'distance_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rateBahtMeta = const VerificationMeta(
    'rateBaht',
  );
  @override
  late final GeneratedColumn<int> rateBaht = GeneratedColumn<int>(
    'rate_baht',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roundsMeta = const VerificationMeta('rounds');
  @override
  late final GeneratedColumn<int> rounds = GeneratedColumn<int>(
    'rounds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    distanceLabel,
    rateBaht,
    rounds,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trip_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<TripRecordData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('distance_label')) {
      context.handle(
        _distanceLabelMeta,
        distanceLabel.isAcceptableOrUnknown(
          data['distance_label']!,
          _distanceLabelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_distanceLabelMeta);
    }
    if (data.containsKey('rate_baht')) {
      context.handle(
        _rateBahtMeta,
        rateBaht.isAcceptableOrUnknown(data['rate_baht']!, _rateBahtMeta),
      );
    } else if (isInserting) {
      context.missing(_rateBahtMeta);
    }
    if (data.containsKey('rounds')) {
      context.handle(
        _roundsMeta,
        rounds.isAcceptableOrUnknown(data['rounds']!, _roundsMeta),
      );
    } else if (isInserting) {
      context.missing(_roundsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TripRecordData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripRecordData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      distanceLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}distance_label'],
      )!,
      rateBaht: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rate_baht'],
      )!,
      rounds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rounds'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TripRecordsTable createAlias(String alias) {
    return $TripRecordsTable(attachedDatabase, alias);
  }
}

class TripRecordData extends DataClass implements Insertable<TripRecordData> {
  final int id;
  final String distanceLabel;
  final int rateBaht;
  final int rounds;
  final DateTime createdAt;
  const TripRecordData({
    required this.id,
    required this.distanceLabel,
    required this.rateBaht,
    required this.rounds,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['distance_label'] = Variable<String>(distanceLabel);
    map['rate_baht'] = Variable<int>(rateBaht);
    map['rounds'] = Variable<int>(rounds);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TripRecordsCompanion toCompanion(bool nullToAbsent) {
    return TripRecordsCompanion(
      id: Value(id),
      distanceLabel: Value(distanceLabel),
      rateBaht: Value(rateBaht),
      rounds: Value(rounds),
      createdAt: Value(createdAt),
    );
  }

  factory TripRecordData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripRecordData(
      id: serializer.fromJson<int>(json['id']),
      distanceLabel: serializer.fromJson<String>(json['distanceLabel']),
      rateBaht: serializer.fromJson<int>(json['rateBaht']),
      rounds: serializer.fromJson<int>(json['rounds']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'distanceLabel': serializer.toJson<String>(distanceLabel),
      'rateBaht': serializer.toJson<int>(rateBaht),
      'rounds': serializer.toJson<int>(rounds),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TripRecordData copyWith({
    int? id,
    String? distanceLabel,
    int? rateBaht,
    int? rounds,
    DateTime? createdAt,
  }) => TripRecordData(
    id: id ?? this.id,
    distanceLabel: distanceLabel ?? this.distanceLabel,
    rateBaht: rateBaht ?? this.rateBaht,
    rounds: rounds ?? this.rounds,
    createdAt: createdAt ?? this.createdAt,
  );
  TripRecordData copyWithCompanion(TripRecordsCompanion data) {
    return TripRecordData(
      id: data.id.present ? data.id.value : this.id,
      distanceLabel: data.distanceLabel.present
          ? data.distanceLabel.value
          : this.distanceLabel,
      rateBaht: data.rateBaht.present ? data.rateBaht.value : this.rateBaht,
      rounds: data.rounds.present ? data.rounds.value : this.rounds,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripRecordData(')
          ..write('id: $id, ')
          ..write('distanceLabel: $distanceLabel, ')
          ..write('rateBaht: $rateBaht, ')
          ..write('rounds: $rounds, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, distanceLabel, rateBaht, rounds, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripRecordData &&
          other.id == this.id &&
          other.distanceLabel == this.distanceLabel &&
          other.rateBaht == this.rateBaht &&
          other.rounds == this.rounds &&
          other.createdAt == this.createdAt);
}

class TripRecordsCompanion extends UpdateCompanion<TripRecordData> {
  final Value<int> id;
  final Value<String> distanceLabel;
  final Value<int> rateBaht;
  final Value<int> rounds;
  final Value<DateTime> createdAt;
  const TripRecordsCompanion({
    this.id = const Value.absent(),
    this.distanceLabel = const Value.absent(),
    this.rateBaht = const Value.absent(),
    this.rounds = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TripRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String distanceLabel,
    required int rateBaht,
    required int rounds,
    required DateTime createdAt,
  }) : distanceLabel = Value(distanceLabel),
       rateBaht = Value(rateBaht),
       rounds = Value(rounds),
       createdAt = Value(createdAt);
  static Insertable<TripRecordData> custom({
    Expression<int>? id,
    Expression<String>? distanceLabel,
    Expression<int>? rateBaht,
    Expression<int>? rounds,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (distanceLabel != null) 'distance_label': distanceLabel,
      if (rateBaht != null) 'rate_baht': rateBaht,
      if (rounds != null) 'rounds': rounds,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TripRecordsCompanion copyWith({
    Value<int>? id,
    Value<String>? distanceLabel,
    Value<int>? rateBaht,
    Value<int>? rounds,
    Value<DateTime>? createdAt,
  }) {
    return TripRecordsCompanion(
      id: id ?? this.id,
      distanceLabel: distanceLabel ?? this.distanceLabel,
      rateBaht: rateBaht ?? this.rateBaht,
      rounds: rounds ?? this.rounds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (distanceLabel.present) {
      map['distance_label'] = Variable<String>(distanceLabel.value);
    }
    if (rateBaht.present) {
      map['rate_baht'] = Variable<int>(rateBaht.value);
    }
    if (rounds.present) {
      map['rounds'] = Variable<int>(rounds.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripRecordsCompanion(')
          ..write('id: $id, ')
          ..write('distanceLabel: $distanceLabel, ')
          ..write('rateBaht: $rateBaht, ')
          ..write('rounds: $rounds, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CustomerRecordsTable customerRecords = $CustomerRecordsTable(
    this,
  );
  late final $TripRecordsTable tripRecords = $TripRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    customerRecords,
    tripRecords,
  ];
}

typedef $$CustomerRecordsTableCreateCompanionBuilder =
    CustomerRecordsCompanion Function({
      required String phone,
      required String name,
      required String address,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$CustomerRecordsTableUpdateCompanionBuilder =
    CustomerRecordsCompanion Function({
      Value<String> phone,
      Value<String> name,
      Value<String> address,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$CustomerRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $CustomerRecordsTable> {
  $$CustomerRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomerRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomerRecordsTable> {
  $$CustomerRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomerRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomerRecordsTable> {
  $$CustomerRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CustomerRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomerRecordsTable,
          CustomerRecordData,
          $$CustomerRecordsTableFilterComposer,
          $$CustomerRecordsTableOrderingComposer,
          $$CustomerRecordsTableAnnotationComposer,
          $$CustomerRecordsTableCreateCompanionBuilder,
          $$CustomerRecordsTableUpdateCompanionBuilder,
          (
            CustomerRecordData,
            BaseReferences<
              _$AppDatabase,
              $CustomerRecordsTable,
              CustomerRecordData
            >,
          ),
          CustomerRecordData,
          PrefetchHooks Function()
        > {
  $$CustomerRecordsTableTableManager(
    _$AppDatabase db,
    $CustomerRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomerRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomerRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomerRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> phone = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomerRecordsCompanion(
                phone: phone,
                name: name,
                address: address,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String phone,
                required String name,
                required String address,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => CustomerRecordsCompanion.insert(
                phone: phone,
                name: name,
                address: address,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomerRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomerRecordsTable,
      CustomerRecordData,
      $$CustomerRecordsTableFilterComposer,
      $$CustomerRecordsTableOrderingComposer,
      $$CustomerRecordsTableAnnotationComposer,
      $$CustomerRecordsTableCreateCompanionBuilder,
      $$CustomerRecordsTableUpdateCompanionBuilder,
      (
        CustomerRecordData,
        BaseReferences<
          _$AppDatabase,
          $CustomerRecordsTable,
          CustomerRecordData
        >,
      ),
      CustomerRecordData,
      PrefetchHooks Function()
    >;
typedef $$TripRecordsTableCreateCompanionBuilder =
    TripRecordsCompanion Function({
      Value<int> id,
      required String distanceLabel,
      required int rateBaht,
      required int rounds,
      required DateTime createdAt,
    });
typedef $$TripRecordsTableUpdateCompanionBuilder =
    TripRecordsCompanion Function({
      Value<int> id,
      Value<String> distanceLabel,
      Value<int> rateBaht,
      Value<int> rounds,
      Value<DateTime> createdAt,
    });

class $$TripRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $TripRecordsTable> {
  $$TripRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get distanceLabel => $composableBuilder(
    column: $table.distanceLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rateBaht => $composableBuilder(
    column: $table.rateBaht,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rounds => $composableBuilder(
    column: $table.rounds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TripRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $TripRecordsTable> {
  $$TripRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get distanceLabel => $composableBuilder(
    column: $table.distanceLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rateBaht => $composableBuilder(
    column: $table.rateBaht,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rounds => $composableBuilder(
    column: $table.rounds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TripRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripRecordsTable> {
  $$TripRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get distanceLabel => $composableBuilder(
    column: $table.distanceLabel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rateBaht =>
      $composableBuilder(column: $table.rateBaht, builder: (column) => column);

  GeneratedColumn<int> get rounds =>
      $composableBuilder(column: $table.rounds, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TripRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripRecordsTable,
          TripRecordData,
          $$TripRecordsTableFilterComposer,
          $$TripRecordsTableOrderingComposer,
          $$TripRecordsTableAnnotationComposer,
          $$TripRecordsTableCreateCompanionBuilder,
          $$TripRecordsTableUpdateCompanionBuilder,
          (
            TripRecordData,
            BaseReferences<_$AppDatabase, $TripRecordsTable, TripRecordData>,
          ),
          TripRecordData,
          PrefetchHooks Function()
        > {
  $$TripRecordsTableTableManager(_$AppDatabase db, $TripRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> distanceLabel = const Value.absent(),
                Value<int> rateBaht = const Value.absent(),
                Value<int> rounds = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TripRecordsCompanion(
                id: id,
                distanceLabel: distanceLabel,
                rateBaht: rateBaht,
                rounds: rounds,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String distanceLabel,
                required int rateBaht,
                required int rounds,
                required DateTime createdAt,
              }) => TripRecordsCompanion.insert(
                id: id,
                distanceLabel: distanceLabel,
                rateBaht: rateBaht,
                rounds: rounds,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TripRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripRecordsTable,
      TripRecordData,
      $$TripRecordsTableFilterComposer,
      $$TripRecordsTableOrderingComposer,
      $$TripRecordsTableAnnotationComposer,
      $$TripRecordsTableCreateCompanionBuilder,
      $$TripRecordsTableUpdateCompanionBuilder,
      (
        TripRecordData,
        BaseReferences<_$AppDatabase, $TripRecordsTable, TripRecordData>,
      ),
      TripRecordData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CustomerRecordsTableTableManager get customerRecords =>
      $$CustomerRecordsTableTableManager(_db, _db.customerRecords);
  $$TripRecordsTableTableManager get tripRecords =>
      $$TripRecordsTableTableManager(_db, _db.tripRecords);
}
