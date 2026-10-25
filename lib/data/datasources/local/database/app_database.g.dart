// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $FarmFieldsTableTable extends FarmFieldsTable
    with TableInfo<$FarmFieldsTableTable, FarmFieldsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FarmFieldsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameArMeta = const VerificationMeta('nameAr');
  @override
  late final GeneratedColumn<String> nameAr = GeneratedColumn<String>(
    'name_ar',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _governorateArMeta = const VerificationMeta(
    'governorateAr',
  );
  @override
  late final GeneratedColumn<String> governorateAr = GeneratedColumn<String>(
    'governorate_ar',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _areaInFeddanMeta = const VerificationMeta(
    'areaInFeddan',
  );
  @override
  late final GeneratedColumn<double> areaInFeddan = GeneratedColumn<double>(
    'area_in_feddan',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _soilTypeMeta = const VerificationMeta(
    'soilType',
  );
  @override
  late final GeneratedColumn<String> soilType = GeneratedColumn<String>(
    'soil_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeCropIdMeta = const VerificationMeta(
    'activeCropId',
  );
  @override
  late final GeneratedColumn<String> activeCropId = GeneratedColumn<String>(
    'active_crop_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nameAr,
    governorateAr,
    latitude,
    longitude,
    areaInFeddan,
    soilType,
    activeCropId,
    isDefault,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'farm_fields_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<FarmFieldsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name_ar')) {
      context.handle(
        _nameArMeta,
        nameAr.isAcceptableOrUnknown(data['name_ar']!, _nameArMeta),
      );
    } else if (isInserting) {
      context.missing(_nameArMeta);
    }
    if (data.containsKey('governorate_ar')) {
      context.handle(
        _governorateArMeta,
        governorateAr.isAcceptableOrUnknown(
          data['governorate_ar']!,
          _governorateArMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_governorateArMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('area_in_feddan')) {
      context.handle(
        _areaInFeddanMeta,
        areaInFeddan.isAcceptableOrUnknown(
          data['area_in_feddan']!,
          _areaInFeddanMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_areaInFeddanMeta);
    }
    if (data.containsKey('soil_type')) {
      context.handle(
        _soilTypeMeta,
        soilType.isAcceptableOrUnknown(data['soil_type']!, _soilTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_soilTypeMeta);
    }
    if (data.containsKey('active_crop_id')) {
      context.handle(
        _activeCropIdMeta,
        activeCropId.isAcceptableOrUnknown(
          data['active_crop_id']!,
          _activeCropIdMeta,
        ),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FarmFieldsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FarmFieldsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nameAr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_ar'],
      )!,
      governorateAr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}governorate_ar'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      areaInFeddan: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}area_in_feddan'],
      )!,
      soilType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}soil_type'],
      )!,
      activeCropId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_crop_id'],
      ),
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $FarmFieldsTableTable createAlias(String alias) {
    return $FarmFieldsTableTable(attachedDatabase, alias);
  }
}

class FarmFieldsTableData extends DataClass
    implements Insertable<FarmFieldsTableData> {
  final String id;
  final String nameAr;
  final String governorateAr;
  final double latitude;
  final double longitude;
  final double areaInFeddan;
  final String soilType;
  final String? activeCropId;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
  const FarmFieldsTableData({
    required this.id,
    required this.nameAr,
    required this.governorateAr,
    required this.latitude,
    required this.longitude,
    required this.areaInFeddan,
    required this.soilType,
    this.activeCropId,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name_ar'] = Variable<String>(nameAr);
    map['governorate_ar'] = Variable<String>(governorateAr);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['area_in_feddan'] = Variable<double>(areaInFeddan);
    map['soil_type'] = Variable<String>(soilType);
    if (!nullToAbsent || activeCropId != null) {
      map['active_crop_id'] = Variable<String>(activeCropId);
    }
    map['is_default'] = Variable<bool>(isDefault);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  FarmFieldsTableCompanion toCompanion(bool nullToAbsent) {
    return FarmFieldsTableCompanion(
      id: Value(id),
      nameAr: Value(nameAr),
      governorateAr: Value(governorateAr),
      latitude: Value(latitude),
      longitude: Value(longitude),
      areaInFeddan: Value(areaInFeddan),
      soilType: Value(soilType),
      activeCropId: activeCropId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeCropId),
      isDefault: Value(isDefault),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory FarmFieldsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FarmFieldsTableData(
      id: serializer.fromJson<String>(json['id']),
      nameAr: serializer.fromJson<String>(json['nameAr']),
      governorateAr: serializer.fromJson<String>(json['governorateAr']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      areaInFeddan: serializer.fromJson<double>(json['areaInFeddan']),
      soilType: serializer.fromJson<String>(json['soilType']),
      activeCropId: serializer.fromJson<String?>(json['activeCropId']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nameAr': serializer.toJson<String>(nameAr),
      'governorateAr': serializer.toJson<String>(governorateAr),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'areaInFeddan': serializer.toJson<double>(areaInFeddan),
      'soilType': serializer.toJson<String>(soilType),
      'activeCropId': serializer.toJson<String?>(activeCropId),
      'isDefault': serializer.toJson<bool>(isDefault),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  FarmFieldsTableData copyWith({
    String? id,
    String? nameAr,
    String? governorateAr,
    double? latitude,
    double? longitude,
    double? areaInFeddan,
    String? soilType,
    Value<String?> activeCropId = const Value.absent(),
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => FarmFieldsTableData(
    id: id ?? this.id,
    nameAr: nameAr ?? this.nameAr,
    governorateAr: governorateAr ?? this.governorateAr,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    areaInFeddan: areaInFeddan ?? this.areaInFeddan,
    soilType: soilType ?? this.soilType,
    activeCropId: activeCropId.present ? activeCropId.value : this.activeCropId,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  FarmFieldsTableData copyWithCompanion(FarmFieldsTableCompanion data) {
    return FarmFieldsTableData(
      id: data.id.present ? data.id.value : this.id,
      nameAr: data.nameAr.present ? data.nameAr.value : this.nameAr,
      governorateAr: data.governorateAr.present
          ? data.governorateAr.value
          : this.governorateAr,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      areaInFeddan: data.areaInFeddan.present
          ? data.areaInFeddan.value
          : this.areaInFeddan,
      soilType: data.soilType.present ? data.soilType.value : this.soilType,
      activeCropId: data.activeCropId.present
          ? data.activeCropId.value
          : this.activeCropId,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FarmFieldsTableData(')
          ..write('id: $id, ')
          ..write('nameAr: $nameAr, ')
          ..write('governorateAr: $governorateAr, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('areaInFeddan: $areaInFeddan, ')
          ..write('soilType: $soilType, ')
          ..write('activeCropId: $activeCropId, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    nameAr,
    governorateAr,
    latitude,
    longitude,
    areaInFeddan,
    soilType,
    activeCropId,
    isDefault,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FarmFieldsTableData &&
          other.id == this.id &&
          other.nameAr == this.nameAr &&
          other.governorateAr == this.governorateAr &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.areaInFeddan == this.areaInFeddan &&
          other.soilType == this.soilType &&
          other.activeCropId == this.activeCropId &&
          other.isDefault == this.isDefault &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FarmFieldsTableCompanion extends UpdateCompanion<FarmFieldsTableData> {
  final Value<String> id;
  final Value<String> nameAr;
  final Value<String> governorateAr;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<double> areaInFeddan;
  final Value<String> soilType;
  final Value<String?> activeCropId;
  final Value<bool> isDefault;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const FarmFieldsTableCompanion({
    this.id = const Value.absent(),
    this.nameAr = const Value.absent(),
    this.governorateAr = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.areaInFeddan = const Value.absent(),
    this.soilType = const Value.absent(),
    this.activeCropId = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FarmFieldsTableCompanion.insert({
    required String id,
    required String nameAr,
    required String governorateAr,
    required double latitude,
    required double longitude,
    required double areaInFeddan,
    required String soilType,
    this.activeCropId = const Value.absent(),
    this.isDefault = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nameAr = Value(nameAr),
       governorateAr = Value(governorateAr),
       latitude = Value(latitude),
       longitude = Value(longitude),
       areaInFeddan = Value(areaInFeddan),
       soilType = Value(soilType),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<FarmFieldsTableData> custom({
    Expression<String>? id,
    Expression<String>? nameAr,
    Expression<String>? governorateAr,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? areaInFeddan,
    Expression<String>? soilType,
    Expression<String>? activeCropId,
    Expression<bool>? isDefault,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nameAr != null) 'name_ar': nameAr,
      if (governorateAr != null) 'governorate_ar': governorateAr,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (areaInFeddan != null) 'area_in_feddan': areaInFeddan,
      if (soilType != null) 'soil_type': soilType,
      if (activeCropId != null) 'active_crop_id': activeCropId,
      if (isDefault != null) 'is_default': isDefault,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FarmFieldsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? nameAr,
    Value<String>? governorateAr,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<double>? areaInFeddan,
    Value<String>? soilType,
    Value<String?>? activeCropId,
    Value<bool>? isDefault,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return FarmFieldsTableCompanion(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      governorateAr: governorateAr ?? this.governorateAr,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      areaInFeddan: areaInFeddan ?? this.areaInFeddan,
      soilType: soilType ?? this.soilType,
      activeCropId: activeCropId ?? this.activeCropId,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nameAr.present) {
      map['name_ar'] = Variable<String>(nameAr.value);
    }
    if (governorateAr.present) {
      map['governorate_ar'] = Variable<String>(governorateAr.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (areaInFeddan.present) {
      map['area_in_feddan'] = Variable<double>(areaInFeddan.value);
    }
    if (soilType.present) {
      map['soil_type'] = Variable<String>(soilType.value);
    }
    if (activeCropId.present) {
      map['active_crop_id'] = Variable<String>(activeCropId.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FarmFieldsTableCompanion(')
          ..write('id: $id, ')
          ..write('nameAr: $nameAr, ')
          ..write('governorateAr: $governorateAr, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('areaInFeddan: $areaInFeddan, ')
          ..write('soilType: $soilType, ')
          ..write('activeCropId: $activeCropId, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeletedDefaultFieldIdsTableTable extends DeletedDefaultFieldIdsTable
    with
        TableInfo<
          $DeletedDefaultFieldIdsTableTable,
          DeletedDefaultFieldIdsTableData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeletedDefaultFieldIdsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deleted_default_field_ids_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeletedDefaultFieldIdsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_deletedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeletedDefaultFieldIdsTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeletedDefaultFieldIdsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      )!,
    );
  }

  @override
  $DeletedDefaultFieldIdsTableTable createAlias(String alias) {
    return $DeletedDefaultFieldIdsTableTable(attachedDatabase, alias);
  }
}

class DeletedDefaultFieldIdsTableData extends DataClass
    implements Insertable<DeletedDefaultFieldIdsTableData> {
  final String id;
  final DateTime deletedAt;
  const DeletedDefaultFieldIdsTableData({
    required this.id,
    required this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['deleted_at'] = Variable<DateTime>(deletedAt);
    return map;
  }

  DeletedDefaultFieldIdsTableCompanion toCompanion(bool nullToAbsent) {
    return DeletedDefaultFieldIdsTableCompanion(
      id: Value(id),
      deletedAt: Value(deletedAt),
    );
  }

  factory DeletedDefaultFieldIdsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeletedDefaultFieldIdsTableData(
      id: serializer.fromJson<String>(json['id']),
      deletedAt: serializer.fromJson<DateTime>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deletedAt': serializer.toJson<DateTime>(deletedAt),
    };
  }

  DeletedDefaultFieldIdsTableData copyWith({String? id, DateTime? deletedAt}) =>
      DeletedDefaultFieldIdsTableData(
        id: id ?? this.id,
        deletedAt: deletedAt ?? this.deletedAt,
      );
  DeletedDefaultFieldIdsTableData copyWithCompanion(
    DeletedDefaultFieldIdsTableCompanion data,
  ) {
    return DeletedDefaultFieldIdsTableData(
      id: data.id.present ? data.id.value : this.id,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeletedDefaultFieldIdsTableData(')
          ..write('id: $id, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeletedDefaultFieldIdsTableData &&
          other.id == this.id &&
          other.deletedAt == this.deletedAt);
}

class DeletedDefaultFieldIdsTableCompanion
    extends UpdateCompanion<DeletedDefaultFieldIdsTableData> {
  final Value<String> id;
  final Value<DateTime> deletedAt;
  final Value<int> rowid;
  const DeletedDefaultFieldIdsTableCompanion({
    this.id = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeletedDefaultFieldIdsTableCompanion.insert({
    required String id,
    required DateTime deletedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deletedAt = Value(deletedAt);
  static Insertable<DeletedDefaultFieldIdsTableData> custom({
    Expression<String>? id,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeletedDefaultFieldIdsTableCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? deletedAt,
    Value<int>? rowid,
  }) {
    return DeletedDefaultFieldIdsTableCompanion(
      id: id ?? this.id,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeletedDefaultFieldIdsTableCompanion(')
          ..write('id: $id, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedDailyRecordsTableTable extends CachedDailyRecordsTable
    with TableInfo<$CachedDailyRecordsTableTable, CachedDailyRecordsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedDailyRecordsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordDateMeta = const VerificationMeta(
    'recordDate',
  );
  @override
  late final GeneratedColumn<DateTime> recordDate = GeneratedColumn<DateTime>(
    'record_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maxTemperatureCMeta = const VerificationMeta(
    'maxTemperatureC',
  );
  @override
  late final GeneratedColumn<double> maxTemperatureC = GeneratedColumn<double>(
    'max_temperature_c',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minTemperatureCMeta = const VerificationMeta(
    'minTemperatureC',
  );
  @override
  late final GeneratedColumn<double> minTemperatureC = GeneratedColumn<double>(
    'min_temperature_c',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _precipitationMmMeta = const VerificationMeta(
    'precipitationMm',
  );
  @override
  late final GeneratedColumn<double> precipitationMm = GeneratedColumn<double>(
    'precipitation_mm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceEt0MmMeta = const VerificationMeta(
    'referenceEt0Mm',
  );
  @override
  late final GeneratedColumn<double> referenceEt0Mm = GeneratedColumn<double>(
    'reference_et0_mm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerNameMeta = const VerificationMeta(
    'providerName',
  );
  @override
  late final GeneratedColumn<String> providerName = GeneratedColumn<String>(
    'provider_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _datasetNameMeta = const VerificationMeta(
    'datasetName',
  );
  @override
  late final GeneratedColumn<String> datasetName = GeneratedColumn<String>(
    'dataset_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requestedLatitudeMeta = const VerificationMeta(
    'requestedLatitude',
  );
  @override
  late final GeneratedColumn<double> requestedLatitude =
      GeneratedColumn<double>(
        'requested_latitude',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _requestedLongitudeMeta =
      const VerificationMeta('requestedLongitude');
  @override
  late final GeneratedColumn<double> requestedLongitude =
      GeneratedColumn<double>(
        'requested_longitude',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _gridLatitudeMeta = const VerificationMeta(
    'gridLatitude',
  );
  @override
  late final GeneratedColumn<double> gridLatitude = GeneratedColumn<double>(
    'grid_latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gridLongitudeMeta = const VerificationMeta(
    'gridLongitude',
  );
  @override
  late final GeneratedColumn<double> gridLongitude = GeneratedColumn<double>(
    'grid_longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gridElevationMetersMeta =
      const VerificationMeta('gridElevationMeters');
  @override
  late final GeneratedColumn<double> gridElevationMeters =
      GeneratedColumn<double>(
        'grid_elevation_meters',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _acquisitionTimestampMeta =
      const VerificationMeta('acquisitionTimestamp');
  @override
  late final GeneratedColumn<DateTime> acquisitionTimestamp =
      GeneratedColumn<DateTime>(
        'acquisition_timestamp',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _scientificDisclaimerArMeta =
      const VerificationMeta('scientificDisclaimerAr');
  @override
  late final GeneratedColumn<String> scientificDisclaimerAr =
      GeneratedColumn<String>(
        'scientific_disclaimer_ar',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    cacheKey,
    recordDate,
    maxTemperatureC,
    minTemperatureC,
    precipitationMm,
    referenceEt0Mm,
    providerName,
    datasetName,
    requestedLatitude,
    requestedLongitude,
    gridLatitude,
    gridLongitude,
    gridElevationMeters,
    acquisitionTimestamp,
    scientificDisclaimerAr,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_daily_records_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedDailyRecordsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('record_date')) {
      context.handle(
        _recordDateMeta,
        recordDate.isAcceptableOrUnknown(data['record_date']!, _recordDateMeta),
      );
    } else if (isInserting) {
      context.missing(_recordDateMeta);
    }
    if (data.containsKey('max_temperature_c')) {
      context.handle(
        _maxTemperatureCMeta,
        maxTemperatureC.isAcceptableOrUnknown(
          data['max_temperature_c']!,
          _maxTemperatureCMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_maxTemperatureCMeta);
    }
    if (data.containsKey('min_temperature_c')) {
      context.handle(
        _minTemperatureCMeta,
        minTemperatureC.isAcceptableOrUnknown(
          data['min_temperature_c']!,
          _minTemperatureCMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_minTemperatureCMeta);
    }
    if (data.containsKey('precipitation_mm')) {
      context.handle(
        _precipitationMmMeta,
        precipitationMm.isAcceptableOrUnknown(
          data['precipitation_mm']!,
          _precipitationMmMeta,
        ),
      );
    }
    if (data.containsKey('reference_et0_mm')) {
      context.handle(
        _referenceEt0MmMeta,
        referenceEt0Mm.isAcceptableOrUnknown(
          data['reference_et0_mm']!,
          _referenceEt0MmMeta,
        ),
      );
    }
    if (data.containsKey('provider_name')) {
      context.handle(
        _providerNameMeta,
        providerName.isAcceptableOrUnknown(
          data['provider_name']!,
          _providerNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerNameMeta);
    }
    if (data.containsKey('dataset_name')) {
      context.handle(
        _datasetNameMeta,
        datasetName.isAcceptableOrUnknown(
          data['dataset_name']!,
          _datasetNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_datasetNameMeta);
    }
    if (data.containsKey('requested_latitude')) {
      context.handle(
        _requestedLatitudeMeta,
        requestedLatitude.isAcceptableOrUnknown(
          data['requested_latitude']!,
          _requestedLatitudeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requestedLatitudeMeta);
    }
    if (data.containsKey('requested_longitude')) {
      context.handle(
        _requestedLongitudeMeta,
        requestedLongitude.isAcceptableOrUnknown(
          data['requested_longitude']!,
          _requestedLongitudeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requestedLongitudeMeta);
    }
    if (data.containsKey('grid_latitude')) {
      context.handle(
        _gridLatitudeMeta,
        gridLatitude.isAcceptableOrUnknown(
          data['grid_latitude']!,
          _gridLatitudeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_gridLatitudeMeta);
    }
    if (data.containsKey('grid_longitude')) {
      context.handle(
        _gridLongitudeMeta,
        gridLongitude.isAcceptableOrUnknown(
          data['grid_longitude']!,
          _gridLongitudeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_gridLongitudeMeta);
    }
    if (data.containsKey('grid_elevation_meters')) {
      context.handle(
        _gridElevationMetersMeta,
        gridElevationMeters.isAcceptableOrUnknown(
          data['grid_elevation_meters']!,
          _gridElevationMetersMeta,
        ),
      );
    }
    if (data.containsKey('acquisition_timestamp')) {
      context.handle(
        _acquisitionTimestampMeta,
        acquisitionTimestamp.isAcceptableOrUnknown(
          data['acquisition_timestamp']!,
          _acquisitionTimestampMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_acquisitionTimestampMeta);
    }
    if (data.containsKey('scientific_disclaimer_ar')) {
      context.handle(
        _scientificDisclaimerArMeta,
        scientificDisclaimerAr.isAcceptableOrUnknown(
          data['scientific_disclaimer_ar']!,
          _scientificDisclaimerArMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scientificDisclaimerArMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey, recordDate};
  @override
  CachedDailyRecordsTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedDailyRecordsTableData(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      recordDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}record_date'],
      )!,
      maxTemperatureC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_temperature_c'],
      )!,
      minTemperatureC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}min_temperature_c'],
      )!,
      precipitationMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}precipitation_mm'],
      ),
      referenceEt0Mm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}reference_et0_mm'],
      ),
      providerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_name'],
      )!,
      datasetName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dataset_name'],
      )!,
      requestedLatitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}requested_latitude'],
      )!,
      requestedLongitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}requested_longitude'],
      )!,
      gridLatitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grid_latitude'],
      )!,
      gridLongitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grid_longitude'],
      )!,
      gridElevationMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grid_elevation_meters'],
      ),
      acquisitionTimestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}acquisition_timestamp'],
      )!,
      scientificDisclaimerAr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scientific_disclaimer_ar'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedDailyRecordsTableTable createAlias(String alias) {
    return $CachedDailyRecordsTableTable(attachedDatabase, alias);
  }
}

class CachedDailyRecordsTableData extends DataClass
    implements Insertable<CachedDailyRecordsTableData> {
  final String cacheKey;
  final DateTime recordDate;
  final double maxTemperatureC;
  final double minTemperatureC;
  final double? precipitationMm;
  final double? referenceEt0Mm;
  final String providerName;
  final String datasetName;
  final double requestedLatitude;
  final double requestedLongitude;
  final double gridLatitude;
  final double gridLongitude;
  final double? gridElevationMeters;
  final DateTime acquisitionTimestamp;
  final String scientificDisclaimerAr;
  final DateTime cachedAt;
  const CachedDailyRecordsTableData({
    required this.cacheKey,
    required this.recordDate,
    required this.maxTemperatureC,
    required this.minTemperatureC,
    this.precipitationMm,
    this.referenceEt0Mm,
    required this.providerName,
    required this.datasetName,
    required this.requestedLatitude,
    required this.requestedLongitude,
    required this.gridLatitude,
    required this.gridLongitude,
    this.gridElevationMeters,
    required this.acquisitionTimestamp,
    required this.scientificDisclaimerAr,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['record_date'] = Variable<DateTime>(recordDate);
    map['max_temperature_c'] = Variable<double>(maxTemperatureC);
    map['min_temperature_c'] = Variable<double>(minTemperatureC);
    if (!nullToAbsent || precipitationMm != null) {
      map['precipitation_mm'] = Variable<double>(precipitationMm);
    }
    if (!nullToAbsent || referenceEt0Mm != null) {
      map['reference_et0_mm'] = Variable<double>(referenceEt0Mm);
    }
    map['provider_name'] = Variable<String>(providerName);
    map['dataset_name'] = Variable<String>(datasetName);
    map['requested_latitude'] = Variable<double>(requestedLatitude);
    map['requested_longitude'] = Variable<double>(requestedLongitude);
    map['grid_latitude'] = Variable<double>(gridLatitude);
    map['grid_longitude'] = Variable<double>(gridLongitude);
    if (!nullToAbsent || gridElevationMeters != null) {
      map['grid_elevation_meters'] = Variable<double>(gridElevationMeters);
    }
    map['acquisition_timestamp'] = Variable<DateTime>(acquisitionTimestamp);
    map['scientific_disclaimer_ar'] = Variable<String>(scientificDisclaimerAr);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedDailyRecordsTableCompanion toCompanion(bool nullToAbsent) {
    return CachedDailyRecordsTableCompanion(
      cacheKey: Value(cacheKey),
      recordDate: Value(recordDate),
      maxTemperatureC: Value(maxTemperatureC),
      minTemperatureC: Value(minTemperatureC),
      precipitationMm: precipitationMm == null && nullToAbsent
          ? const Value.absent()
          : Value(precipitationMm),
      referenceEt0Mm: referenceEt0Mm == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceEt0Mm),
      providerName: Value(providerName),
      datasetName: Value(datasetName),
      requestedLatitude: Value(requestedLatitude),
      requestedLongitude: Value(requestedLongitude),
      gridLatitude: Value(gridLatitude),
      gridLongitude: Value(gridLongitude),
      gridElevationMeters: gridElevationMeters == null && nullToAbsent
          ? const Value.absent()
          : Value(gridElevationMeters),
      acquisitionTimestamp: Value(acquisitionTimestamp),
      scientificDisclaimerAr: Value(scientificDisclaimerAr),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedDailyRecordsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedDailyRecordsTableData(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      recordDate: serializer.fromJson<DateTime>(json['recordDate']),
      maxTemperatureC: serializer.fromJson<double>(json['maxTemperatureC']),
      minTemperatureC: serializer.fromJson<double>(json['minTemperatureC']),
      precipitationMm: serializer.fromJson<double?>(json['precipitationMm']),
      referenceEt0Mm: serializer.fromJson<double?>(json['referenceEt0Mm']),
      providerName: serializer.fromJson<String>(json['providerName']),
      datasetName: serializer.fromJson<String>(json['datasetName']),
      requestedLatitude: serializer.fromJson<double>(json['requestedLatitude']),
      requestedLongitude: serializer.fromJson<double>(
        json['requestedLongitude'],
      ),
      gridLatitude: serializer.fromJson<double>(json['gridLatitude']),
      gridLongitude: serializer.fromJson<double>(json['gridLongitude']),
      gridElevationMeters: serializer.fromJson<double?>(
        json['gridElevationMeters'],
      ),
      acquisitionTimestamp: serializer.fromJson<DateTime>(
        json['acquisitionTimestamp'],
      ),
      scientificDisclaimerAr: serializer.fromJson<String>(
        json['scientificDisclaimerAr'],
      ),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'recordDate': serializer.toJson<DateTime>(recordDate),
      'maxTemperatureC': serializer.toJson<double>(maxTemperatureC),
      'minTemperatureC': serializer.toJson<double>(minTemperatureC),
      'precipitationMm': serializer.toJson<double?>(precipitationMm),
      'referenceEt0Mm': serializer.toJson<double?>(referenceEt0Mm),
      'providerName': serializer.toJson<String>(providerName),
      'datasetName': serializer.toJson<String>(datasetName),
      'requestedLatitude': serializer.toJson<double>(requestedLatitude),
      'requestedLongitude': serializer.toJson<double>(requestedLongitude),
      'gridLatitude': serializer.toJson<double>(gridLatitude),
      'gridLongitude': serializer.toJson<double>(gridLongitude),
      'gridElevationMeters': serializer.toJson<double?>(gridElevationMeters),
      'acquisitionTimestamp': serializer.toJson<DateTime>(acquisitionTimestamp),
      'scientificDisclaimerAr': serializer.toJson<String>(
        scientificDisclaimerAr,
      ),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedDailyRecordsTableData copyWith({
    String? cacheKey,
    DateTime? recordDate,
    double? maxTemperatureC,
    double? minTemperatureC,
    Value<double?> precipitationMm = const Value.absent(),
    Value<double?> referenceEt0Mm = const Value.absent(),
    String? providerName,
    String? datasetName,
    double? requestedLatitude,
    double? requestedLongitude,
    double? gridLatitude,
    double? gridLongitude,
    Value<double?> gridElevationMeters = const Value.absent(),
    DateTime? acquisitionTimestamp,
    String? scientificDisclaimerAr,
    DateTime? cachedAt,
  }) => CachedDailyRecordsTableData(
    cacheKey: cacheKey ?? this.cacheKey,
    recordDate: recordDate ?? this.recordDate,
    maxTemperatureC: maxTemperatureC ?? this.maxTemperatureC,
    minTemperatureC: minTemperatureC ?? this.minTemperatureC,
    precipitationMm: precipitationMm.present
        ? precipitationMm.value
        : this.precipitationMm,
    referenceEt0Mm: referenceEt0Mm.present
        ? referenceEt0Mm.value
        : this.referenceEt0Mm,
    providerName: providerName ?? this.providerName,
    datasetName: datasetName ?? this.datasetName,
    requestedLatitude: requestedLatitude ?? this.requestedLatitude,
    requestedLongitude: requestedLongitude ?? this.requestedLongitude,
    gridLatitude: gridLatitude ?? this.gridLatitude,
    gridLongitude: gridLongitude ?? this.gridLongitude,
    gridElevationMeters: gridElevationMeters.present
        ? gridElevationMeters.value
        : this.gridElevationMeters,
    acquisitionTimestamp: acquisitionTimestamp ?? this.acquisitionTimestamp,
    scientificDisclaimerAr:
        scientificDisclaimerAr ?? this.scientificDisclaimerAr,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedDailyRecordsTableData copyWithCompanion(
    CachedDailyRecordsTableCompanion data,
  ) {
    return CachedDailyRecordsTableData(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      recordDate: data.recordDate.present
          ? data.recordDate.value
          : this.recordDate,
      maxTemperatureC: data.maxTemperatureC.present
          ? data.maxTemperatureC.value
          : this.maxTemperatureC,
      minTemperatureC: data.minTemperatureC.present
          ? data.minTemperatureC.value
          : this.minTemperatureC,
      precipitationMm: data.precipitationMm.present
          ? data.precipitationMm.value
          : this.precipitationMm,
      referenceEt0Mm: data.referenceEt0Mm.present
          ? data.referenceEt0Mm.value
          : this.referenceEt0Mm,
      providerName: data.providerName.present
          ? data.providerName.value
          : this.providerName,
      datasetName: data.datasetName.present
          ? data.datasetName.value
          : this.datasetName,
      requestedLatitude: data.requestedLatitude.present
          ? data.requestedLatitude.value
          : this.requestedLatitude,
      requestedLongitude: data.requestedLongitude.present
          ? data.requestedLongitude.value
          : this.requestedLongitude,
      gridLatitude: data.gridLatitude.present
          ? data.gridLatitude.value
          : this.gridLatitude,
      gridLongitude: data.gridLongitude.present
          ? data.gridLongitude.value
          : this.gridLongitude,
      gridElevationMeters: data.gridElevationMeters.present
          ? data.gridElevationMeters.value
          : this.gridElevationMeters,
      acquisitionTimestamp: data.acquisitionTimestamp.present
          ? data.acquisitionTimestamp.value
          : this.acquisitionTimestamp,
      scientificDisclaimerAr: data.scientificDisclaimerAr.present
          ? data.scientificDisclaimerAr.value
          : this.scientificDisclaimerAr,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedDailyRecordsTableData(')
          ..write('cacheKey: $cacheKey, ')
          ..write('recordDate: $recordDate, ')
          ..write('maxTemperatureC: $maxTemperatureC, ')
          ..write('minTemperatureC: $minTemperatureC, ')
          ..write('precipitationMm: $precipitationMm, ')
          ..write('referenceEt0Mm: $referenceEt0Mm, ')
          ..write('providerName: $providerName, ')
          ..write('datasetName: $datasetName, ')
          ..write('requestedLatitude: $requestedLatitude, ')
          ..write('requestedLongitude: $requestedLongitude, ')
          ..write('gridLatitude: $gridLatitude, ')
          ..write('gridLongitude: $gridLongitude, ')
          ..write('gridElevationMeters: $gridElevationMeters, ')
          ..write('acquisitionTimestamp: $acquisitionTimestamp, ')
          ..write('scientificDisclaimerAr: $scientificDisclaimerAr, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    cacheKey,
    recordDate,
    maxTemperatureC,
    minTemperatureC,
    precipitationMm,
    referenceEt0Mm,
    providerName,
    datasetName,
    requestedLatitude,
    requestedLongitude,
    gridLatitude,
    gridLongitude,
    gridElevationMeters,
    acquisitionTimestamp,
    scientificDisclaimerAr,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedDailyRecordsTableData &&
          other.cacheKey == this.cacheKey &&
          other.recordDate == this.recordDate &&
          other.maxTemperatureC == this.maxTemperatureC &&
          other.minTemperatureC == this.minTemperatureC &&
          other.precipitationMm == this.precipitationMm &&
          other.referenceEt0Mm == this.referenceEt0Mm &&
          other.providerName == this.providerName &&
          other.datasetName == this.datasetName &&
          other.requestedLatitude == this.requestedLatitude &&
          other.requestedLongitude == this.requestedLongitude &&
          other.gridLatitude == this.gridLatitude &&
          other.gridLongitude == this.gridLongitude &&
          other.gridElevationMeters == this.gridElevationMeters &&
          other.acquisitionTimestamp == this.acquisitionTimestamp &&
          other.scientificDisclaimerAr == this.scientificDisclaimerAr &&
          other.cachedAt == this.cachedAt);
}

class CachedDailyRecordsTableCompanion
    extends UpdateCompanion<CachedDailyRecordsTableData> {
  final Value<String> cacheKey;
  final Value<DateTime> recordDate;
  final Value<double> maxTemperatureC;
  final Value<double> minTemperatureC;
  final Value<double?> precipitationMm;
  final Value<double?> referenceEt0Mm;
  final Value<String> providerName;
  final Value<String> datasetName;
  final Value<double> requestedLatitude;
  final Value<double> requestedLongitude;
  final Value<double> gridLatitude;
  final Value<double> gridLongitude;
  final Value<double?> gridElevationMeters;
  final Value<DateTime> acquisitionTimestamp;
  final Value<String> scientificDisclaimerAr;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedDailyRecordsTableCompanion({
    this.cacheKey = const Value.absent(),
    this.recordDate = const Value.absent(),
    this.maxTemperatureC = const Value.absent(),
    this.minTemperatureC = const Value.absent(),
    this.precipitationMm = const Value.absent(),
    this.referenceEt0Mm = const Value.absent(),
    this.providerName = const Value.absent(),
    this.datasetName = const Value.absent(),
    this.requestedLatitude = const Value.absent(),
    this.requestedLongitude = const Value.absent(),
    this.gridLatitude = const Value.absent(),
    this.gridLongitude = const Value.absent(),
    this.gridElevationMeters = const Value.absent(),
    this.acquisitionTimestamp = const Value.absent(),
    this.scientificDisclaimerAr = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedDailyRecordsTableCompanion.insert({
    required String cacheKey,
    required DateTime recordDate,
    required double maxTemperatureC,
    required double minTemperatureC,
    this.precipitationMm = const Value.absent(),
    this.referenceEt0Mm = const Value.absent(),
    required String providerName,
    required String datasetName,
    required double requestedLatitude,
    required double requestedLongitude,
    required double gridLatitude,
    required double gridLongitude,
    this.gridElevationMeters = const Value.absent(),
    required DateTime acquisitionTimestamp,
    required String scientificDisclaimerAr,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       recordDate = Value(recordDate),
       maxTemperatureC = Value(maxTemperatureC),
       minTemperatureC = Value(minTemperatureC),
       providerName = Value(providerName),
       datasetName = Value(datasetName),
       requestedLatitude = Value(requestedLatitude),
       requestedLongitude = Value(requestedLongitude),
       gridLatitude = Value(gridLatitude),
       gridLongitude = Value(gridLongitude),
       acquisitionTimestamp = Value(acquisitionTimestamp),
       scientificDisclaimerAr = Value(scientificDisclaimerAr),
       cachedAt = Value(cachedAt);
  static Insertable<CachedDailyRecordsTableData> custom({
    Expression<String>? cacheKey,
    Expression<DateTime>? recordDate,
    Expression<double>? maxTemperatureC,
    Expression<double>? minTemperatureC,
    Expression<double>? precipitationMm,
    Expression<double>? referenceEt0Mm,
    Expression<String>? providerName,
    Expression<String>? datasetName,
    Expression<double>? requestedLatitude,
    Expression<double>? requestedLongitude,
    Expression<double>? gridLatitude,
    Expression<double>? gridLongitude,
    Expression<double>? gridElevationMeters,
    Expression<DateTime>? acquisitionTimestamp,
    Expression<String>? scientificDisclaimerAr,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (recordDate != null) 'record_date': recordDate,
      if (maxTemperatureC != null) 'max_temperature_c': maxTemperatureC,
      if (minTemperatureC != null) 'min_temperature_c': minTemperatureC,
      if (precipitationMm != null) 'precipitation_mm': precipitationMm,
      if (referenceEt0Mm != null) 'reference_et0_mm': referenceEt0Mm,
      if (providerName != null) 'provider_name': providerName,
      if (datasetName != null) 'dataset_name': datasetName,
      if (requestedLatitude != null) 'requested_latitude': requestedLatitude,
      if (requestedLongitude != null) 'requested_longitude': requestedLongitude,
      if (gridLatitude != null) 'grid_latitude': gridLatitude,
      if (gridLongitude != null) 'grid_longitude': gridLongitude,
      if (gridElevationMeters != null)
        'grid_elevation_meters': gridElevationMeters,
      if (acquisitionTimestamp != null)
        'acquisition_timestamp': acquisitionTimestamp,
      if (scientificDisclaimerAr != null)
        'scientific_disclaimer_ar': scientificDisclaimerAr,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedDailyRecordsTableCompanion copyWith({
    Value<String>? cacheKey,
    Value<DateTime>? recordDate,
    Value<double>? maxTemperatureC,
    Value<double>? minTemperatureC,
    Value<double?>? precipitationMm,
    Value<double?>? referenceEt0Mm,
    Value<String>? providerName,
    Value<String>? datasetName,
    Value<double>? requestedLatitude,
    Value<double>? requestedLongitude,
    Value<double>? gridLatitude,
    Value<double>? gridLongitude,
    Value<double?>? gridElevationMeters,
    Value<DateTime>? acquisitionTimestamp,
    Value<String>? scientificDisclaimerAr,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedDailyRecordsTableCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      recordDate: recordDate ?? this.recordDate,
      maxTemperatureC: maxTemperatureC ?? this.maxTemperatureC,
      minTemperatureC: minTemperatureC ?? this.minTemperatureC,
      precipitationMm: precipitationMm ?? this.precipitationMm,
      referenceEt0Mm: referenceEt0Mm ?? this.referenceEt0Mm,
      providerName: providerName ?? this.providerName,
      datasetName: datasetName ?? this.datasetName,
      requestedLatitude: requestedLatitude ?? this.requestedLatitude,
      requestedLongitude: requestedLongitude ?? this.requestedLongitude,
      gridLatitude: gridLatitude ?? this.gridLatitude,
      gridLongitude: gridLongitude ?? this.gridLongitude,
      gridElevationMeters: gridElevationMeters ?? this.gridElevationMeters,
      acquisitionTimestamp: acquisitionTimestamp ?? this.acquisitionTimestamp,
      scientificDisclaimerAr:
          scientificDisclaimerAr ?? this.scientificDisclaimerAr,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (recordDate.present) {
      map['record_date'] = Variable<DateTime>(recordDate.value);
    }
    if (maxTemperatureC.present) {
      map['max_temperature_c'] = Variable<double>(maxTemperatureC.value);
    }
    if (minTemperatureC.present) {
      map['min_temperature_c'] = Variable<double>(minTemperatureC.value);
    }
    if (precipitationMm.present) {
      map['precipitation_mm'] = Variable<double>(precipitationMm.value);
    }
    if (referenceEt0Mm.present) {
      map['reference_et0_mm'] = Variable<double>(referenceEt0Mm.value);
    }
    if (providerName.present) {
      map['provider_name'] = Variable<String>(providerName.value);
    }
    if (datasetName.present) {
      map['dataset_name'] = Variable<String>(datasetName.value);
    }
    if (requestedLatitude.present) {
      map['requested_latitude'] = Variable<double>(requestedLatitude.value);
    }
    if (requestedLongitude.present) {
      map['requested_longitude'] = Variable<double>(requestedLongitude.value);
    }
    if (gridLatitude.present) {
      map['grid_latitude'] = Variable<double>(gridLatitude.value);
    }
    if (gridLongitude.present) {
      map['grid_longitude'] = Variable<double>(gridLongitude.value);
    }
    if (gridElevationMeters.present) {
      map['grid_elevation_meters'] = Variable<double>(
        gridElevationMeters.value,
      );
    }
    if (acquisitionTimestamp.present) {
      map['acquisition_timestamp'] = Variable<DateTime>(
        acquisitionTimestamp.value,
      );
    }
    if (scientificDisclaimerAr.present) {
      map['scientific_disclaimer_ar'] = Variable<String>(
        scientificDisclaimerAr.value,
      );
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedDailyRecordsTableCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('recordDate: $recordDate, ')
          ..write('maxTemperatureC: $maxTemperatureC, ')
          ..write('minTemperatureC: $minTemperatureC, ')
          ..write('precipitationMm: $precipitationMm, ')
          ..write('referenceEt0Mm: $referenceEt0Mm, ')
          ..write('providerName: $providerName, ')
          ..write('datasetName: $datasetName, ')
          ..write('requestedLatitude: $requestedLatitude, ')
          ..write('requestedLongitude: $requestedLongitude, ')
          ..write('gridLatitude: $gridLatitude, ')
          ..write('gridLongitude: $gridLongitude, ')
          ..write('gridElevationMeters: $gridElevationMeters, ')
          ..write('acquisitionTimestamp: $acquisitionTimestamp, ')
          ..write('scientificDisclaimerAr: $scientificDisclaimerAr, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FarmFieldsTableTable farmFieldsTable = $FarmFieldsTableTable(
    this,
  );
  late final $DeletedDefaultFieldIdsTableTable deletedDefaultFieldIdsTable =
      $DeletedDefaultFieldIdsTableTable(this);
  late final $CachedDailyRecordsTableTable cachedDailyRecordsTable =
      $CachedDailyRecordsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    farmFieldsTable,
    deletedDefaultFieldIdsTable,
    cachedDailyRecordsTable,
  ];
}

typedef $$FarmFieldsTableTableCreateCompanionBuilder =
    FarmFieldsTableCompanion Function({
      required String id,
      required String nameAr,
      required String governorateAr,
      required double latitude,
      required double longitude,
      required double areaInFeddan,
      required String soilType,
      Value<String?> activeCropId,
      Value<bool> isDefault,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$FarmFieldsTableTableUpdateCompanionBuilder =
    FarmFieldsTableCompanion Function({
      Value<String> id,
      Value<String> nameAr,
      Value<String> governorateAr,
      Value<double> latitude,
      Value<double> longitude,
      Value<double> areaInFeddan,
      Value<String> soilType,
      Value<String?> activeCropId,
      Value<bool> isDefault,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$FarmFieldsTableTableFilterComposer
    extends Composer<_$AppDatabase, $FarmFieldsTableTable> {
  $$FarmFieldsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameAr => $composableBuilder(
    column: $table.nameAr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get governorateAr => $composableBuilder(
    column: $table.governorateAr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get areaInFeddan => $composableBuilder(
    column: $table.areaInFeddan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get soilType => $composableBuilder(
    column: $table.soilType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeCropId => $composableBuilder(
    column: $table.activeCropId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FarmFieldsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FarmFieldsTableTable> {
  $$FarmFieldsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameAr => $composableBuilder(
    column: $table.nameAr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get governorateAr => $composableBuilder(
    column: $table.governorateAr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get areaInFeddan => $composableBuilder(
    column: $table.areaInFeddan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get soilType => $composableBuilder(
    column: $table.soilType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeCropId => $composableBuilder(
    column: $table.activeCropId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FarmFieldsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FarmFieldsTableTable> {
  $$FarmFieldsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nameAr =>
      $composableBuilder(column: $table.nameAr, builder: (column) => column);

  GeneratedColumn<String> get governorateAr => $composableBuilder(
    column: $table.governorateAr,
    builder: (column) => column,
  );

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get areaInFeddan => $composableBuilder(
    column: $table.areaInFeddan,
    builder: (column) => column,
  );

  GeneratedColumn<String> get soilType =>
      $composableBuilder(column: $table.soilType, builder: (column) => column);

  GeneratedColumn<String> get activeCropId => $composableBuilder(
    column: $table.activeCropId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$FarmFieldsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FarmFieldsTableTable,
          FarmFieldsTableData,
          $$FarmFieldsTableTableFilterComposer,
          $$FarmFieldsTableTableOrderingComposer,
          $$FarmFieldsTableTableAnnotationComposer,
          $$FarmFieldsTableTableCreateCompanionBuilder,
          $$FarmFieldsTableTableUpdateCompanionBuilder,
          (
            FarmFieldsTableData,
            BaseReferences<
              _$AppDatabase,
              $FarmFieldsTableTable,
              FarmFieldsTableData
            >,
          ),
          FarmFieldsTableData,
          PrefetchHooks Function()
        > {
  $$FarmFieldsTableTableTableManager(
    _$AppDatabase db,
    $FarmFieldsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FarmFieldsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FarmFieldsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FarmFieldsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nameAr = const Value.absent(),
                Value<String> governorateAr = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<double> areaInFeddan = const Value.absent(),
                Value<String> soilType = const Value.absent(),
                Value<String?> activeCropId = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FarmFieldsTableCompanion(
                id: id,
                nameAr: nameAr,
                governorateAr: governorateAr,
                latitude: latitude,
                longitude: longitude,
                areaInFeddan: areaInFeddan,
                soilType: soilType,
                activeCropId: activeCropId,
                isDefault: isDefault,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nameAr,
                required String governorateAr,
                required double latitude,
                required double longitude,
                required double areaInFeddan,
                required String soilType,
                Value<String?> activeCropId = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => FarmFieldsTableCompanion.insert(
                id: id,
                nameAr: nameAr,
                governorateAr: governorateAr,
                latitude: latitude,
                longitude: longitude,
                areaInFeddan: areaInFeddan,
                soilType: soilType,
                activeCropId: activeCropId,
                isDefault: isDefault,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FarmFieldsTableTable, FarmFieldsTableData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $FarmFieldsTableTable,
                    FarmFieldsTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FarmFieldsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FarmFieldsTableTable,
      FarmFieldsTableData,
      $$FarmFieldsTableTableFilterComposer,
      $$FarmFieldsTableTableOrderingComposer,
      $$FarmFieldsTableTableAnnotationComposer,
      $$FarmFieldsTableTableCreateCompanionBuilder,
      $$FarmFieldsTableTableUpdateCompanionBuilder,
      (
        FarmFieldsTableData,
        BaseReferences<
          _$AppDatabase,
          $FarmFieldsTableTable,
          FarmFieldsTableData
        >,
      ),
      FarmFieldsTableData,
      PrefetchHooks Function()
    >;
typedef $$DeletedDefaultFieldIdsTableTableCreateCompanionBuilder =
    DeletedDefaultFieldIdsTableCompanion Function({
      required String id,
      required DateTime deletedAt,
      Value<int> rowid,
    });
typedef $$DeletedDefaultFieldIdsTableTableUpdateCompanionBuilder =
    DeletedDefaultFieldIdsTableCompanion Function({
      Value<String> id,
      Value<DateTime> deletedAt,
      Value<int> rowid,
    });

class $$DeletedDefaultFieldIdsTableTableFilterComposer
    extends Composer<_$AppDatabase, $DeletedDefaultFieldIdsTableTable> {
  $$DeletedDefaultFieldIdsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeletedDefaultFieldIdsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DeletedDefaultFieldIdsTableTable> {
  $$DeletedDefaultFieldIdsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeletedDefaultFieldIdsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeletedDefaultFieldIdsTableTable> {
  $$DeletedDefaultFieldIdsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$DeletedDefaultFieldIdsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeletedDefaultFieldIdsTableTable,
          DeletedDefaultFieldIdsTableData,
          $$DeletedDefaultFieldIdsTableTableFilterComposer,
          $$DeletedDefaultFieldIdsTableTableOrderingComposer,
          $$DeletedDefaultFieldIdsTableTableAnnotationComposer,
          $$DeletedDefaultFieldIdsTableTableCreateCompanionBuilder,
          $$DeletedDefaultFieldIdsTableTableUpdateCompanionBuilder,
          (
            DeletedDefaultFieldIdsTableData,
            BaseReferences<
              _$AppDatabase,
              $DeletedDefaultFieldIdsTableTable,
              DeletedDefaultFieldIdsTableData
            >,
          ),
          DeletedDefaultFieldIdsTableData,
          PrefetchHooks Function()
        > {
  $$DeletedDefaultFieldIdsTableTableTableManager(
    _$AppDatabase db,
    $DeletedDefaultFieldIdsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeletedDefaultFieldIdsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DeletedDefaultFieldIdsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DeletedDefaultFieldIdsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeletedDefaultFieldIdsTableCompanion(
                id: id,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime deletedAt,
                Value<int> rowid = const Value.absent(),
              }) => DeletedDefaultFieldIdsTableCompanion.insert(
                id: id,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $DeletedDefaultFieldIdsTableTable,
                    DeletedDefaultFieldIdsTableData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DeletedDefaultFieldIdsTableTable,
                    DeletedDefaultFieldIdsTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeletedDefaultFieldIdsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeletedDefaultFieldIdsTableTable,
      DeletedDefaultFieldIdsTableData,
      $$DeletedDefaultFieldIdsTableTableFilterComposer,
      $$DeletedDefaultFieldIdsTableTableOrderingComposer,
      $$DeletedDefaultFieldIdsTableTableAnnotationComposer,
      $$DeletedDefaultFieldIdsTableTableCreateCompanionBuilder,
      $$DeletedDefaultFieldIdsTableTableUpdateCompanionBuilder,
      (
        DeletedDefaultFieldIdsTableData,
        BaseReferences<
          _$AppDatabase,
          $DeletedDefaultFieldIdsTableTable,
          DeletedDefaultFieldIdsTableData
        >,
      ),
      DeletedDefaultFieldIdsTableData,
      PrefetchHooks Function()
    >;
typedef $$CachedDailyRecordsTableTableCreateCompanionBuilder =
    CachedDailyRecordsTableCompanion Function({
      required String cacheKey,
      required DateTime recordDate,
      required double maxTemperatureC,
      required double minTemperatureC,
      Value<double?> precipitationMm,
      Value<double?> referenceEt0Mm,
      required String providerName,
      required String datasetName,
      required double requestedLatitude,
      required double requestedLongitude,
      required double gridLatitude,
      required double gridLongitude,
      Value<double?> gridElevationMeters,
      required DateTime acquisitionTimestamp,
      required String scientificDisclaimerAr,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedDailyRecordsTableTableUpdateCompanionBuilder =
    CachedDailyRecordsTableCompanion Function({
      Value<String> cacheKey,
      Value<DateTime> recordDate,
      Value<double> maxTemperatureC,
      Value<double> minTemperatureC,
      Value<double?> precipitationMm,
      Value<double?> referenceEt0Mm,
      Value<String> providerName,
      Value<String> datasetName,
      Value<double> requestedLatitude,
      Value<double> requestedLongitude,
      Value<double> gridLatitude,
      Value<double> gridLongitude,
      Value<double?> gridElevationMeters,
      Value<DateTime> acquisitionTimestamp,
      Value<String> scientificDisclaimerAr,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedDailyRecordsTableTableFilterComposer
    extends Composer<_$AppDatabase, $CachedDailyRecordsTableTable> {
  $$CachedDailyRecordsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordDate => $composableBuilder(
    column: $table.recordDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxTemperatureC => $composableBuilder(
    column: $table.maxTemperatureC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get minTemperatureC => $composableBuilder(
    column: $table.minTemperatureC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get precipitationMm => $composableBuilder(
    column: $table.precipitationMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get referenceEt0Mm => $composableBuilder(
    column: $table.referenceEt0Mm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get datasetName => $composableBuilder(
    column: $table.datasetName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get requestedLatitude => $composableBuilder(
    column: $table.requestedLatitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get requestedLongitude => $composableBuilder(
    column: $table.requestedLongitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gridLatitude => $composableBuilder(
    column: $table.gridLatitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gridLongitude => $composableBuilder(
    column: $table.gridLongitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gridElevationMeters => $composableBuilder(
    column: $table.gridElevationMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get acquisitionTimestamp => $composableBuilder(
    column: $table.acquisitionTimestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scientificDisclaimerAr => $composableBuilder(
    column: $table.scientificDisclaimerAr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedDailyRecordsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedDailyRecordsTableTable> {
  $$CachedDailyRecordsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordDate => $composableBuilder(
    column: $table.recordDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxTemperatureC => $composableBuilder(
    column: $table.maxTemperatureC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minTemperatureC => $composableBuilder(
    column: $table.minTemperatureC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get precipitationMm => $composableBuilder(
    column: $table.precipitationMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get referenceEt0Mm => $composableBuilder(
    column: $table.referenceEt0Mm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get datasetName => $composableBuilder(
    column: $table.datasetName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get requestedLatitude => $composableBuilder(
    column: $table.requestedLatitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get requestedLongitude => $composableBuilder(
    column: $table.requestedLongitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gridLatitude => $composableBuilder(
    column: $table.gridLatitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gridLongitude => $composableBuilder(
    column: $table.gridLongitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gridElevationMeters => $composableBuilder(
    column: $table.gridElevationMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get acquisitionTimestamp => $composableBuilder(
    column: $table.acquisitionTimestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scientificDisclaimerAr => $composableBuilder(
    column: $table.scientificDisclaimerAr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedDailyRecordsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedDailyRecordsTableTable> {
  $$CachedDailyRecordsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<DateTime> get recordDate => $composableBuilder(
    column: $table.recordDate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxTemperatureC => $composableBuilder(
    column: $table.maxTemperatureC,
    builder: (column) => column,
  );

  GeneratedColumn<double> get minTemperatureC => $composableBuilder(
    column: $table.minTemperatureC,
    builder: (column) => column,
  );

  GeneratedColumn<double> get precipitationMm => $composableBuilder(
    column: $table.precipitationMm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get referenceEt0Mm => $composableBuilder(
    column: $table.referenceEt0Mm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get datasetName => $composableBuilder(
    column: $table.datasetName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get requestedLatitude => $composableBuilder(
    column: $table.requestedLatitude,
    builder: (column) => column,
  );

  GeneratedColumn<double> get requestedLongitude => $composableBuilder(
    column: $table.requestedLongitude,
    builder: (column) => column,
  );

  GeneratedColumn<double> get gridLatitude => $composableBuilder(
    column: $table.gridLatitude,
    builder: (column) => column,
  );

  GeneratedColumn<double> get gridLongitude => $composableBuilder(
    column: $table.gridLongitude,
    builder: (column) => column,
  );

  GeneratedColumn<double> get gridElevationMeters => $composableBuilder(
    column: $table.gridElevationMeters,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get acquisitionTimestamp => $composableBuilder(
    column: $table.acquisitionTimestamp,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scientificDisclaimerAr => $composableBuilder(
    column: $table.scientificDisclaimerAr,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedDailyRecordsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedDailyRecordsTableTable,
          CachedDailyRecordsTableData,
          $$CachedDailyRecordsTableTableFilterComposer,
          $$CachedDailyRecordsTableTableOrderingComposer,
          $$CachedDailyRecordsTableTableAnnotationComposer,
          $$CachedDailyRecordsTableTableCreateCompanionBuilder,
          $$CachedDailyRecordsTableTableUpdateCompanionBuilder,
          (
            CachedDailyRecordsTableData,
            BaseReferences<
              _$AppDatabase,
              $CachedDailyRecordsTableTable,
              CachedDailyRecordsTableData
            >,
          ),
          CachedDailyRecordsTableData,
          PrefetchHooks Function()
        > {
  $$CachedDailyRecordsTableTableTableManager(
    _$AppDatabase db,
    $CachedDailyRecordsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedDailyRecordsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CachedDailyRecordsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedDailyRecordsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<DateTime> recordDate = const Value.absent(),
                Value<double> maxTemperatureC = const Value.absent(),
                Value<double> minTemperatureC = const Value.absent(),
                Value<double?> precipitationMm = const Value.absent(),
                Value<double?> referenceEt0Mm = const Value.absent(),
                Value<String> providerName = const Value.absent(),
                Value<String> datasetName = const Value.absent(),
                Value<double> requestedLatitude = const Value.absent(),
                Value<double> requestedLongitude = const Value.absent(),
                Value<double> gridLatitude = const Value.absent(),
                Value<double> gridLongitude = const Value.absent(),
                Value<double?> gridElevationMeters = const Value.absent(),
                Value<DateTime> acquisitionTimestamp = const Value.absent(),
                Value<String> scientificDisclaimerAr = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedDailyRecordsTableCompanion(
                cacheKey: cacheKey,
                recordDate: recordDate,
                maxTemperatureC: maxTemperatureC,
                minTemperatureC: minTemperatureC,
                precipitationMm: precipitationMm,
                referenceEt0Mm: referenceEt0Mm,
                providerName: providerName,
                datasetName: datasetName,
                requestedLatitude: requestedLatitude,
                requestedLongitude: requestedLongitude,
                gridLatitude: gridLatitude,
                gridLongitude: gridLongitude,
                gridElevationMeters: gridElevationMeters,
                acquisitionTimestamp: acquisitionTimestamp,
                scientificDisclaimerAr: scientificDisclaimerAr,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required DateTime recordDate,
                required double maxTemperatureC,
                required double minTemperatureC,
                Value<double?> precipitationMm = const Value.absent(),
                Value<double?> referenceEt0Mm = const Value.absent(),
                required String providerName,
                required String datasetName,
                required double requestedLatitude,
                required double requestedLongitude,
                required double gridLatitude,
                required double gridLongitude,
                Value<double?> gridElevationMeters = const Value.absent(),
                required DateTime acquisitionTimestamp,
                required String scientificDisclaimerAr,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedDailyRecordsTableCompanion.insert(
                cacheKey: cacheKey,
                recordDate: recordDate,
                maxTemperatureC: maxTemperatureC,
                minTemperatureC: minTemperatureC,
                precipitationMm: precipitationMm,
                referenceEt0Mm: referenceEt0Mm,
                providerName: providerName,
                datasetName: datasetName,
                requestedLatitude: requestedLatitude,
                requestedLongitude: requestedLongitude,
                gridLatitude: gridLatitude,
                gridLongitude: gridLongitude,
                gridElevationMeters: gridElevationMeters,
                acquisitionTimestamp: acquisitionTimestamp,
                scientificDisclaimerAr: scientificDisclaimerAr,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $CachedDailyRecordsTableTable,
                    CachedDailyRecordsTableData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedDailyRecordsTableTable,
                    CachedDailyRecordsTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedDailyRecordsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedDailyRecordsTableTable,
      CachedDailyRecordsTableData,
      $$CachedDailyRecordsTableTableFilterComposer,
      $$CachedDailyRecordsTableTableOrderingComposer,
      $$CachedDailyRecordsTableTableAnnotationComposer,
      $$CachedDailyRecordsTableTableCreateCompanionBuilder,
      $$CachedDailyRecordsTableTableUpdateCompanionBuilder,
      (
        CachedDailyRecordsTableData,
        BaseReferences<
          _$AppDatabase,
          $CachedDailyRecordsTableTable,
          CachedDailyRecordsTableData
        >,
      ),
      CachedDailyRecordsTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FarmFieldsTableTableTableManager get farmFieldsTable =>
      $$FarmFieldsTableTableTableManager(_db, _db.farmFieldsTable);
  $$DeletedDefaultFieldIdsTableTableTableManager
  get deletedDefaultFieldIdsTable =>
      $$DeletedDefaultFieldIdsTableTableTableManager(
        _db,
        _db.deletedDefaultFieldIdsTable,
      );
  $$CachedDailyRecordsTableTableTableManager get cachedDailyRecordsTable =>
      $$CachedDailyRecordsTableTableTableManager(
        _db,
        _db.cachedDailyRecordsTable,
      );
}
