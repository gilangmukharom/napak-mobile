// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_database.dart';

// ignore_for_file: type=lint
class $PendingPointsTable extends PendingPoints
    with TableInfo<$PendingPointsTable, PendingPoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingPointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _altMeta = const VerificationMeta('alt');
  @override
  late final GeneratedColumn<double> alt = GeneratedColumn<double>(
    'alt',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accuracyMeta = const VerificationMeta(
    'accuracy',
  );
  @override
  late final GeneratedColumn<double> accuracy = GeneratedColumn<double>(
    'accuracy',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speedMpsMeta = const VerificationMeta(
    'speedMps',
  );
  @override
  late final GeneratedColumn<double> speedMps = GeneratedColumn<double>(
    'speed_mps',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transportModeMeta = const VerificationMeta(
    'transportMode',
  );
  @override
  late final GeneratedColumn<String> transportMode = GeneratedColumn<String>(
    'transport_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('tidak_diketahui'),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoUrlMeta = const VerificationMeta(
    'photoUrl',
  );
  @override
  late final GeneratedColumn<String> photoUrl = GeneratedColumn<String>(
    'photo_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    clientId,
    tripId,
    lat,
    lng,
    alt,
    accuracy,
    recordedAt,
    speedMps,
    transportMode,
    note,
    photoUrl,
    attempts,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingPoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    } else if (isInserting) {
      context.missing(_lngMeta);
    }
    if (data.containsKey('alt')) {
      context.handle(
        _altMeta,
        alt.isAcceptableOrUnknown(data['alt']!, _altMeta),
      );
    }
    if (data.containsKey('accuracy')) {
      context.handle(
        _accuracyMeta,
        accuracy.isAcceptableOrUnknown(data['accuracy']!, _accuracyMeta),
      );
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    if (data.containsKey('speed_mps')) {
      context.handle(
        _speedMpsMeta,
        speedMps.isAcceptableOrUnknown(data['speed_mps']!, _speedMpsMeta),
      );
    }
    if (data.containsKey('transport_mode')) {
      context.handle(
        _transportModeMeta,
        transportMode.isAcceptableOrUnknown(
          data['transport_mode']!,
          _transportModeMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('photo_url')) {
      context.handle(
        _photoUrlMeta,
        photoUrl.isAcceptableOrUnknown(data['photo_url']!, _photoUrlMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientId};
  @override
  PendingPoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingPoint(
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      )!,
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      )!,
      alt: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}alt'],
      ),
      accuracy: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}accuracy'],
      ),
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
      speedMps: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed_mps'],
      ),
      transportMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transport_mode'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      photoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_url'],
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
    );
  }

  @override
  $PendingPointsTable createAlias(String alias) {
    return $PendingPointsTable(attachedDatabase, alias);
  }
}

class PendingPoint extends DataClass implements Insertable<PendingPoint> {
  /// Dibuat di perangkat saat titiknya direkam. Server memakainya untuk
  /// mengenali kiriman ulang, jadi sinkron dua kali tidak menggandakan jejak.
  final String clientId;
  final String tripId;
  final double lat;
  final double lng;
  final double? alt;
  final double? accuracy;
  final DateTime recordedAt;
  final double? speedMps;
  final String transportMode;
  final String? note;
  final String? photoUrl;

  /// Berapa kali pengiriman titik ini gagal. Dipakai untuk menahan diri
  /// mencoba terus-menerus saat ada yang benar-benar salah.
  final int attempts;
  const PendingPoint({
    required this.clientId,
    required this.tripId,
    required this.lat,
    required this.lng,
    this.alt,
    this.accuracy,
    required this.recordedAt,
    this.speedMps,
    required this.transportMode,
    this.note,
    this.photoUrl,
    required this.attempts,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_id'] = Variable<String>(clientId);
    map['trip_id'] = Variable<String>(tripId);
    map['lat'] = Variable<double>(lat);
    map['lng'] = Variable<double>(lng);
    if (!nullToAbsent || alt != null) {
      map['alt'] = Variable<double>(alt);
    }
    if (!nullToAbsent || accuracy != null) {
      map['accuracy'] = Variable<double>(accuracy);
    }
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    if (!nullToAbsent || speedMps != null) {
      map['speed_mps'] = Variable<double>(speedMps);
    }
    map['transport_mode'] = Variable<String>(transportMode);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || photoUrl != null) {
      map['photo_url'] = Variable<String>(photoUrl);
    }
    map['attempts'] = Variable<int>(attempts);
    return map;
  }

  PendingPointsCompanion toCompanion(bool nullToAbsent) {
    return PendingPointsCompanion(
      clientId: Value(clientId),
      tripId: Value(tripId),
      lat: Value(lat),
      lng: Value(lng),
      alt: alt == null && nullToAbsent ? const Value.absent() : Value(alt),
      accuracy: accuracy == null && nullToAbsent
          ? const Value.absent()
          : Value(accuracy),
      recordedAt: Value(recordedAt),
      speedMps: speedMps == null && nullToAbsent
          ? const Value.absent()
          : Value(speedMps),
      transportMode: Value(transportMode),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      photoUrl: photoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(photoUrl),
      attempts: Value(attempts),
    );
  }

  factory PendingPoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingPoint(
      clientId: serializer.fromJson<String>(json['clientId']),
      tripId: serializer.fromJson<String>(json['tripId']),
      lat: serializer.fromJson<double>(json['lat']),
      lng: serializer.fromJson<double>(json['lng']),
      alt: serializer.fromJson<double?>(json['alt']),
      accuracy: serializer.fromJson<double?>(json['accuracy']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
      speedMps: serializer.fromJson<double?>(json['speedMps']),
      transportMode: serializer.fromJson<String>(json['transportMode']),
      note: serializer.fromJson<String?>(json['note']),
      photoUrl: serializer.fromJson<String?>(json['photoUrl']),
      attempts: serializer.fromJson<int>(json['attempts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientId': serializer.toJson<String>(clientId),
      'tripId': serializer.toJson<String>(tripId),
      'lat': serializer.toJson<double>(lat),
      'lng': serializer.toJson<double>(lng),
      'alt': serializer.toJson<double?>(alt),
      'accuracy': serializer.toJson<double?>(accuracy),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
      'speedMps': serializer.toJson<double?>(speedMps),
      'transportMode': serializer.toJson<String>(transportMode),
      'note': serializer.toJson<String?>(note),
      'photoUrl': serializer.toJson<String?>(photoUrl),
      'attempts': serializer.toJson<int>(attempts),
    };
  }

  PendingPoint copyWith({
    String? clientId,
    String? tripId,
    double? lat,
    double? lng,
    Value<double?> alt = const Value.absent(),
    Value<double?> accuracy = const Value.absent(),
    DateTime? recordedAt,
    Value<double?> speedMps = const Value.absent(),
    String? transportMode,
    Value<String?> note = const Value.absent(),
    Value<String?> photoUrl = const Value.absent(),
    int? attempts,
  }) => PendingPoint(
    clientId: clientId ?? this.clientId,
    tripId: tripId ?? this.tripId,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    alt: alt.present ? alt.value : this.alt,
    accuracy: accuracy.present ? accuracy.value : this.accuracy,
    recordedAt: recordedAt ?? this.recordedAt,
    speedMps: speedMps.present ? speedMps.value : this.speedMps,
    transportMode: transportMode ?? this.transportMode,
    note: note.present ? note.value : this.note,
    photoUrl: photoUrl.present ? photoUrl.value : this.photoUrl,
    attempts: attempts ?? this.attempts,
  );
  PendingPoint copyWithCompanion(PendingPointsCompanion data) {
    return PendingPoint(
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      alt: data.alt.present ? data.alt.value : this.alt,
      accuracy: data.accuracy.present ? data.accuracy.value : this.accuracy,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
      speedMps: data.speedMps.present ? data.speedMps.value : this.speedMps,
      transportMode: data.transportMode.present
          ? data.transportMode.value
          : this.transportMode,
      note: data.note.present ? data.note.value : this.note,
      photoUrl: data.photoUrl.present ? data.photoUrl.value : this.photoUrl,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingPoint(')
          ..write('clientId: $clientId, ')
          ..write('tripId: $tripId, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('alt: $alt, ')
          ..write('accuracy: $accuracy, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('speedMps: $speedMps, ')
          ..write('transportMode: $transportMode, ')
          ..write('note: $note, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    clientId,
    tripId,
    lat,
    lng,
    alt,
    accuracy,
    recordedAt,
    speedMps,
    transportMode,
    note,
    photoUrl,
    attempts,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingPoint &&
          other.clientId == this.clientId &&
          other.tripId == this.tripId &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.alt == this.alt &&
          other.accuracy == this.accuracy &&
          other.recordedAt == this.recordedAt &&
          other.speedMps == this.speedMps &&
          other.transportMode == this.transportMode &&
          other.note == this.note &&
          other.photoUrl == this.photoUrl &&
          other.attempts == this.attempts);
}

class PendingPointsCompanion extends UpdateCompanion<PendingPoint> {
  final Value<String> clientId;
  final Value<String> tripId;
  final Value<double> lat;
  final Value<double> lng;
  final Value<double?> alt;
  final Value<double?> accuracy;
  final Value<DateTime> recordedAt;
  final Value<double?> speedMps;
  final Value<String> transportMode;
  final Value<String?> note;
  final Value<String?> photoUrl;
  final Value<int> attempts;
  final Value<int> rowid;
  const PendingPointsCompanion({
    this.clientId = const Value.absent(),
    this.tripId = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.alt = const Value.absent(),
    this.accuracy = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.speedMps = const Value.absent(),
    this.transportMode = const Value.absent(),
    this.note = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.attempts = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingPointsCompanion.insert({
    required String clientId,
    required String tripId,
    required double lat,
    required double lng,
    this.alt = const Value.absent(),
    this.accuracy = const Value.absent(),
    required DateTime recordedAt,
    this.speedMps = const Value.absent(),
    this.transportMode = const Value.absent(),
    this.note = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.attempts = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : clientId = Value(clientId),
       tripId = Value(tripId),
       lat = Value(lat),
       lng = Value(lng),
       recordedAt = Value(recordedAt);
  static Insertable<PendingPoint> custom({
    Expression<String>? clientId,
    Expression<String>? tripId,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<double>? alt,
    Expression<double>? accuracy,
    Expression<DateTime>? recordedAt,
    Expression<double>? speedMps,
    Expression<String>? transportMode,
    Expression<String>? note,
    Expression<String>? photoUrl,
    Expression<int>? attempts,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (tripId != null) 'trip_id': tripId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (alt != null) 'alt': alt,
      if (accuracy != null) 'accuracy': accuracy,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (speedMps != null) 'speed_mps': speedMps,
      if (transportMode != null) 'transport_mode': transportMode,
      if (note != null) 'note': note,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (attempts != null) 'attempts': attempts,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingPointsCompanion copyWith({
    Value<String>? clientId,
    Value<String>? tripId,
    Value<double>? lat,
    Value<double>? lng,
    Value<double?>? alt,
    Value<double?>? accuracy,
    Value<DateTime>? recordedAt,
    Value<double?>? speedMps,
    Value<String>? transportMode,
    Value<String?>? note,
    Value<String?>? photoUrl,
    Value<int>? attempts,
    Value<int>? rowid,
  }) {
    return PendingPointsCompanion(
      clientId: clientId ?? this.clientId,
      tripId: tripId ?? this.tripId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      alt: alt ?? this.alt,
      accuracy: accuracy ?? this.accuracy,
      recordedAt: recordedAt ?? this.recordedAt,
      speedMps: speedMps ?? this.speedMps,
      transportMode: transportMode ?? this.transportMode,
      note: note ?? this.note,
      photoUrl: photoUrl ?? this.photoUrl,
      attempts: attempts ?? this.attempts,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (alt.present) {
      map['alt'] = Variable<double>(alt.value);
    }
    if (accuracy.present) {
      map['accuracy'] = Variable<double>(accuracy.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (speedMps.present) {
      map['speed_mps'] = Variable<double>(speedMps.value);
    }
    if (transportMode.present) {
      map['transport_mode'] = Variable<String>(transportMode.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (photoUrl.present) {
      map['photo_url'] = Variable<String>(photoUrl.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingPointsCompanion(')
          ..write('clientId: $clientId, ')
          ..write('tripId: $tripId, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('alt: $alt, ')
          ..write('accuracy: $accuracy, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('speedMps: $speedMps, ')
          ..write('transportMode: $transportMode, ')
          ..write('note: $note, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('attempts: $attempts, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$NapakLocalDatabase extends GeneratedDatabase {
  _$NapakLocalDatabase(QueryExecutor e) : super(e);
  $NapakLocalDatabaseManager get managers => $NapakLocalDatabaseManager(this);
  late final $PendingPointsTable pendingPoints = $PendingPointsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [pendingPoints];
}

typedef $$PendingPointsTableCreateCompanionBuilder =
    PendingPointsCompanion Function({
      required String clientId,
      required String tripId,
      required double lat,
      required double lng,
      Value<double?> alt,
      Value<double?> accuracy,
      required DateTime recordedAt,
      Value<double?> speedMps,
      Value<String> transportMode,
      Value<String?> note,
      Value<String?> photoUrl,
      Value<int> attempts,
      Value<int> rowid,
    });
typedef $$PendingPointsTableUpdateCompanionBuilder =
    PendingPointsCompanion Function({
      Value<String> clientId,
      Value<String> tripId,
      Value<double> lat,
      Value<double> lng,
      Value<double?> alt,
      Value<double?> accuracy,
      Value<DateTime> recordedAt,
      Value<double?> speedMps,
      Value<String> transportMode,
      Value<String?> note,
      Value<String?> photoUrl,
      Value<int> attempts,
      Value<int> rowid,
    });

class $$PendingPointsTableFilterComposer
    extends Composer<_$NapakLocalDatabase, $PendingPointsTable> {
  $$PendingPointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get alt => $composableBuilder(
    column: $table.alt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speedMps => $composableBuilder(
    column: $table.speedMps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transportMode => $composableBuilder(
    column: $table.transportMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoUrl => $composableBuilder(
    column: $table.photoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingPointsTableOrderingComposer
    extends Composer<_$NapakLocalDatabase, $PendingPointsTable> {
  $$PendingPointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get alt => $composableBuilder(
    column: $table.alt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speedMps => $composableBuilder(
    column: $table.speedMps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transportMode => $composableBuilder(
    column: $table.transportMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoUrl => $composableBuilder(
    column: $table.photoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingPointsTableAnnotationComposer
    extends Composer<_$NapakLocalDatabase, $PendingPointsTable> {
  $$PendingPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<String> get tripId =>
      $composableBuilder(column: $table.tripId, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<double> get alt =>
      $composableBuilder(column: $table.alt, builder: (column) => column);

  GeneratedColumn<double> get accuracy =>
      $composableBuilder(column: $table.accuracy, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get speedMps =>
      $composableBuilder(column: $table.speedMps, builder: (column) => column);

  GeneratedColumn<String> get transportMode => $composableBuilder(
    column: $table.transportMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get photoUrl =>
      $composableBuilder(column: $table.photoUrl, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);
}

class $$PendingPointsTableTableManager
    extends
        RootTableManager<
          _$NapakLocalDatabase,
          $PendingPointsTable,
          PendingPoint,
          $$PendingPointsTableFilterComposer,
          $$PendingPointsTableOrderingComposer,
          $$PendingPointsTableAnnotationComposer,
          $$PendingPointsTableCreateCompanionBuilder,
          $$PendingPointsTableUpdateCompanionBuilder,
          (
            PendingPoint,
            BaseReferences<
              _$NapakLocalDatabase,
              $PendingPointsTable,
              PendingPoint
            >,
          ),
          PendingPoint,
          PrefetchHooks Function()
        > {
  $$PendingPointsTableTableManager(
    _$NapakLocalDatabase db,
    $PendingPointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingPointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingPointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> clientId = const Value.absent(),
                Value<String> tripId = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lng = const Value.absent(),
                Value<double?> alt = const Value.absent(),
                Value<double?> accuracy = const Value.absent(),
                Value<DateTime> recordedAt = const Value.absent(),
                Value<double?> speedMps = const Value.absent(),
                Value<String> transportMode = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> photoUrl = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingPointsCompanion(
                clientId: clientId,
                tripId: tripId,
                lat: lat,
                lng: lng,
                alt: alt,
                accuracy: accuracy,
                recordedAt: recordedAt,
                speedMps: speedMps,
                transportMode: transportMode,
                note: note,
                photoUrl: photoUrl,
                attempts: attempts,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String clientId,
                required String tripId,
                required double lat,
                required double lng,
                Value<double?> alt = const Value.absent(),
                Value<double?> accuracy = const Value.absent(),
                required DateTime recordedAt,
                Value<double?> speedMps = const Value.absent(),
                Value<String> transportMode = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> photoUrl = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingPointsCompanion.insert(
                clientId: clientId,
                tripId: tripId,
                lat: lat,
                lng: lng,
                alt: alt,
                accuracy: accuracy,
                recordedAt: recordedAt,
                speedMps: speedMps,
                transportMode: transportMode,
                note: note,
                photoUrl: photoUrl,
                attempts: attempts,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingPointsTable, PendingPoint>(table),
                  BaseReferences<
                    _$NapakLocalDatabase,
                    $PendingPointsTable,
                    PendingPoint
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingPointsTableProcessedTableManager =
    ProcessedTableManager<
      _$NapakLocalDatabase,
      $PendingPointsTable,
      PendingPoint,
      $$PendingPointsTableFilterComposer,
      $$PendingPointsTableOrderingComposer,
      $$PendingPointsTableAnnotationComposer,
      $$PendingPointsTableCreateCompanionBuilder,
      $$PendingPointsTableUpdateCompanionBuilder,
      (
        PendingPoint,
        BaseReferences<_$NapakLocalDatabase, $PendingPointsTable, PendingPoint>,
      ),
      PendingPoint,
      PrefetchHooks Function()
    >;

class $NapakLocalDatabaseManager {
  final _$NapakLocalDatabase _db;
  $NapakLocalDatabaseManager(this._db);
  $$PendingPointsTableTableManager get pendingPoints =>
      $$PendingPointsTableTableManager(_db, _db.pendingPoints);
}
