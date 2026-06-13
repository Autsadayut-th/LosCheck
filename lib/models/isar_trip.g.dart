// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'isar_trip.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetIsarTripCollection on Isar {
  IsarCollection<IsarTrip> get isarTrips => this.collection();
}

const IsarTripSchema = CollectionSchema(
  name: r'IsarTrip',
  id: 3939607042902198784,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'distanceLabel': PropertySchema(
      id: 1,
      name: r'distanceLabel',
      type: IsarType.string,
    ),
    r'rateBaht': PropertySchema(
      id: 2,
      name: r'rateBaht',
      type: IsarType.long,
    ),
    r'rounds': PropertySchema(
      id: 3,
      name: r'rounds',
      type: IsarType.long,
    )
  },
  estimateSize: _isarTripEstimateSize,
  serialize: _isarTripSerialize,
  deserialize: _isarTripDeserialize,
  deserializeProp: _isarTripDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _isarTripGetId,
  getLinks: _isarTripGetLinks,
  attach: _isarTripAttach,
  version: '3.1.0+1',
);

int _isarTripEstimateSize(
  IsarTrip object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.distanceLabel.length * 3;
  return bytesCount;
}

void _isarTripSerialize(
  IsarTrip object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeString(offsets[1], object.distanceLabel);
  writer.writeLong(offsets[2], object.rateBaht);
  writer.writeLong(offsets[3], object.rounds);
}

IsarTrip _isarTripDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = IsarTrip();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.distanceLabel = reader.readString(offsets[1]);
  object.id = id;
  object.rateBaht = reader.readLong(offsets[2]);
  object.rounds = reader.readLong(offsets[3]);
  return object;
}

P _isarTripDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _isarTripGetId(IsarTrip object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _isarTripGetLinks(IsarTrip object) {
  return [];
}

void _isarTripAttach(IsarCollection<dynamic> col, Id id, IsarTrip object) {
  object.id = id;
}

extension IsarTripQueryWhereSort on QueryBuilder<IsarTrip, IsarTrip, QWhere> {
  QueryBuilder<IsarTrip, IsarTrip, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension IsarTripQueryWhere on QueryBuilder<IsarTrip, IsarTrip, QWhereClause> {
  QueryBuilder<IsarTrip, IsarTrip, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension IsarTripQueryFilter
    on QueryBuilder<IsarTrip, IsarTrip, QFilterCondition> {
  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> createdAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> distanceLabelEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'distanceLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition>
      distanceLabelGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'distanceLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> distanceLabelLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'distanceLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> distanceLabelBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'distanceLabel',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition>
      distanceLabelStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'distanceLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> distanceLabelEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'distanceLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> distanceLabelContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'distanceLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> distanceLabelMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'distanceLabel',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition>
      distanceLabelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'distanceLabel',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition>
      distanceLabelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'distanceLabel',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> rateBahtEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rateBaht',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> rateBahtGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'rateBaht',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> rateBahtLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'rateBaht',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> rateBahtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'rateBaht',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> roundsEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rounds',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> roundsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'rounds',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> roundsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'rounds',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterFilterCondition> roundsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'rounds',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension IsarTripQueryObject
    on QueryBuilder<IsarTrip, IsarTrip, QFilterCondition> {}

extension IsarTripQueryLinks
    on QueryBuilder<IsarTrip, IsarTrip, QFilterCondition> {}

extension IsarTripQuerySortBy on QueryBuilder<IsarTrip, IsarTrip, QSortBy> {
  QueryBuilder<IsarTrip, IsarTrip, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterSortBy> sortByDistanceLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'distanceLabel', Sort.asc);
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterSortBy> sortByDistanceLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'distanceLabel', Sort.desc);
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterSortBy> sortByRateBaht() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rateBaht', Sort.asc);
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterSortBy> sortByRateBahtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rateBaht', Sort.desc);
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterSortBy> sortByRounds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rounds', Sort.asc);
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterSortBy> sortByRoundsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rounds', Sort.desc);
    });
  }
}

extension IsarTripQuerySortThenBy
    on QueryBuilder<IsarTrip, IsarTrip, QSortThenBy> {
  QueryBuilder<IsarTrip, IsarTrip, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterSortBy> thenByDistanceLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'distanceLabel', Sort.asc);
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterSortBy> thenByDistanceLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'distanceLabel', Sort.desc);
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterSortBy> thenByRateBaht() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rateBaht', Sort.asc);
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterSortBy> thenByRateBahtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rateBaht', Sort.desc);
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterSortBy> thenByRounds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rounds', Sort.asc);
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QAfterSortBy> thenByRoundsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rounds', Sort.desc);
    });
  }
}

extension IsarTripQueryWhereDistinct
    on QueryBuilder<IsarTrip, IsarTrip, QDistinct> {
  QueryBuilder<IsarTrip, IsarTrip, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QDistinct> distinctByDistanceLabel(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'distanceLabel',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QDistinct> distinctByRateBaht() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rateBaht');
    });
  }

  QueryBuilder<IsarTrip, IsarTrip, QDistinct> distinctByRounds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rounds');
    });
  }
}

extension IsarTripQueryProperty
    on QueryBuilder<IsarTrip, IsarTrip, QQueryProperty> {
  QueryBuilder<IsarTrip, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<IsarTrip, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<IsarTrip, String, QQueryOperations> distanceLabelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'distanceLabel');
    });
  }

  QueryBuilder<IsarTrip, int, QQueryOperations> rateBahtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rateBaht');
    });
  }

  QueryBuilder<IsarTrip, int, QQueryOperations> roundsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rounds');
    });
  }
}
