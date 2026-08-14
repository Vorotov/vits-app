// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SupplementsTable extends Supplements
    with TableInfo<$SupplementsTable, Supplement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SupplementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
  static const VerificationMeta _doseTextMeta = const VerificationMeta(
    'doseText',
  );
  @override
  late final GeneratedColumn<String> doseText = GeneratedColumn<String>(
    'dose_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    name,
    doseText,
    colorValue,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'supplements';
  @override
  VerificationContext validateIntegrity(
    Insertable<Supplement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('dose_text')) {
      context.handle(
        _doseTextMeta,
        doseText.isAcceptableOrUnknown(data['dose_text']!, _doseTextMeta),
      );
    } else if (isInserting) {
      context.missing(_doseTextMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    } else if (isInserting) {
      context.missing(_noteMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Supplement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Supplement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      doseText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dose_text'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
    );
  }

  @override
  $SupplementsTable createAlias(String alias) {
    return $SupplementsTable(attachedDatabase, alias);
  }
}

class Supplement extends DataClass implements Insertable<Supplement> {
  /// TEXT UUID primary key — generated by repositories via `Uuid().v4()`,
  /// never by the database (no auto-increment, per DATA-02).
  final String id;

  /// True UTC instant of row creation.
  final DateTime createdAt;

  /// True UTC instant of last modification.
  final DateTime updatedAt;

  /// Soft-delete marker: null while the row is live (DATA-02 — no hard
  /// deletes).
  final DateTime? deletedAt;
  final String name;
  final String doseText;

  /// ARGB color int used as the supplement's tag color in charts.
  final int colorValue;
  final String note;
  const Supplement({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.name,
    required this.doseText,
    required this.colorValue,
    required this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['name'] = Variable<String>(name);
    map['dose_text'] = Variable<String>(doseText);
    map['color_value'] = Variable<int>(colorValue);
    map['note'] = Variable<String>(note);
    return map;
  }

  SupplementsCompanion toCompanion(bool nullToAbsent) {
    return SupplementsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      name: Value(name),
      doseText: Value(doseText),
      colorValue: Value(colorValue),
      note: Value(note),
    );
  }

  factory Supplement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Supplement(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      name: serializer.fromJson<String>(json['name']),
      doseText: serializer.fromJson<String>(json['doseText']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      note: serializer.fromJson<String>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'name': serializer.toJson<String>(name),
      'doseText': serializer.toJson<String>(doseText),
      'colorValue': serializer.toJson<int>(colorValue),
      'note': serializer.toJson<String>(note),
    };
  }

  Supplement copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? name,
    String? doseText,
    int? colorValue,
    String? note,
  }) => Supplement(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    name: name ?? this.name,
    doseText: doseText ?? this.doseText,
    colorValue: colorValue ?? this.colorValue,
    note: note ?? this.note,
  );
  Supplement copyWithCompanion(SupplementsCompanion data) {
    return Supplement(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      name: data.name.present ? data.name.value : this.name,
      doseText: data.doseText.present ? data.doseText.value : this.doseText,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Supplement(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('name: $name, ')
          ..write('doseText: $doseText, ')
          ..write('colorValue: $colorValue, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    name,
    doseText,
    colorValue,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Supplement &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.name == this.name &&
          other.doseText == this.doseText &&
          other.colorValue == this.colorValue &&
          other.note == this.note);
}

class SupplementsCompanion extends UpdateCompanion<Supplement> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> name;
  final Value<String> doseText;
  final Value<int> colorValue;
  final Value<String> note;
  final Value<int> rowid;
  const SupplementsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.name = const Value.absent(),
    this.doseText = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SupplementsCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    required String name,
    required String doseText,
    required int colorValue,
    required String note,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       name = Value(name),
       doseText = Value(doseText),
       colorValue = Value(colorValue),
       note = Value(note);
  static Insertable<Supplement> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? name,
    Expression<String>? doseText,
    Expression<int>? colorValue,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (name != null) 'name': name,
      if (doseText != null) 'dose_text': doseText,
      if (colorValue != null) 'color_value': colorValue,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SupplementsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? name,
    Value<String>? doseText,
    Value<int>? colorValue,
    Value<String>? note,
    Value<int>? rowid,
  }) {
    return SupplementsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      name: name ?? this.name,
      doseText: doseText ?? this.doseText,
      colorValue: colorValue ?? this.colorValue,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (doseText.present) {
      map['dose_text'] = Variable<String>(doseText.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SupplementsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('name: $name, ')
          ..write('doseText: $doseText, ')
          ..write('colorValue: $colorValue, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RegimensTable extends Regimens with TableInfo<$RegimensTable, Regimen> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RegimensTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _supplementIdMeta = const VerificationMeta(
    'supplementId',
  );
  @override
  late final GeneratedColumn<String> supplementId = GeneratedColumn<String>(
    'supplement_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES supplements (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<RegimenKind, int> kind =
      GeneratedColumn<int>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<RegimenKind>($RegimensTable.$converterkind);
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _onDaysMeta = const VerificationMeta('onDays');
  @override
  late final GeneratedColumn<int> onDays = GeneratedColumn<int>(
    'on_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _offDaysMeta = const VerificationMeta(
    'offDays',
  );
  @override
  late final GeneratedColumn<int> offDays = GeneratedColumn<int>(
    'off_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pausedMeta = const VerificationMeta('paused');
  @override
  late final GeneratedColumn<bool> paused = GeneratedColumn<bool>(
    'paused',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("paused" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    supplementId,
    kind,
    startDate,
    endDate,
    onDays,
    offDays,
    paused,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'regimens';
  @override
  VerificationContext validateIntegrity(
    Insertable<Regimen> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('supplement_id')) {
      context.handle(
        _supplementIdMeta,
        supplementId.isAcceptableOrUnknown(
          data['supplement_id']!,
          _supplementIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_supplementIdMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('on_days')) {
      context.handle(
        _onDaysMeta,
        onDays.isAcceptableOrUnknown(data['on_days']!, _onDaysMeta),
      );
    }
    if (data.containsKey('off_days')) {
      context.handle(
        _offDaysMeta,
        offDays.isAcceptableOrUnknown(data['off_days']!, _offDaysMeta),
      );
    }
    if (data.containsKey('paused')) {
      context.handle(
        _pausedMeta,
        paused.isAcceptableOrUnknown(data['paused']!, _pausedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Regimen map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Regimen(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      supplementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supplement_id'],
      )!,
      kind: $RegimensTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}kind'],
        )!,
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      ),
      onDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}on_days'],
      )!,
      offDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}off_days'],
      )!,
      paused: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}paused'],
      )!,
    );
  }

  @override
  $RegimensTable createAlias(String alias) {
    return $RegimensTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RegimenKind, int, int> $converterkind =
      const EnumIndexConverter<RegimenKind>(RegimenKind.values);
}

class Regimen extends DataClass implements Insertable<Regimen> {
  /// TEXT UUID primary key — generated by repositories via `Uuid().v4()`,
  /// never by the database (no auto-increment, per DATA-02).
  final String id;

  /// True UTC instant of row creation.
  final DateTime createdAt;

  /// True UTC instant of last modification.
  final DateTime updatedAt;

  /// Soft-delete marker: null while the row is live (DATA-02 — no hard
  /// deletes).
  final DateTime? deletedAt;
  final String supplementId;

  /// Stored as [RegimenKind.index].
  final RegimenKind kind;

  /// Date-only value: always UTC midnight (`DateTime.utc(y, m, d)`).
  final DateTime startDate;

  /// Inclusive last active day for course regimens; null otherwise.
  /// Date-only value: always UTC midnight.
  final DateTime? endDate;
  final int onDays;
  final int offDays;
  final bool paused;
  const Regimen({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.supplementId,
    required this.kind,
    required this.startDate,
    this.endDate,
    required this.onDays,
    required this.offDays,
    required this.paused,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['supplement_id'] = Variable<String>(supplementId);
    {
      map['kind'] = Variable<int>($RegimensTable.$converterkind.toSql(kind));
    }
    map['start_date'] = Variable<DateTime>(startDate);
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    map['on_days'] = Variable<int>(onDays);
    map['off_days'] = Variable<int>(offDays);
    map['paused'] = Variable<bool>(paused);
    return map;
  }

  RegimensCompanion toCompanion(bool nullToAbsent) {
    return RegimensCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      supplementId: Value(supplementId),
      kind: Value(kind),
      startDate: Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      onDays: Value(onDays),
      offDays: Value(offDays),
      paused: Value(paused),
    );
  }

  factory Regimen.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Regimen(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      supplementId: serializer.fromJson<String>(json['supplementId']),
      kind: $RegimensTable.$converterkind.fromJson(
        serializer.fromJson<int>(json['kind']),
      ),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      onDays: serializer.fromJson<int>(json['onDays']),
      offDays: serializer.fromJson<int>(json['offDays']),
      paused: serializer.fromJson<bool>(json['paused']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'supplementId': serializer.toJson<String>(supplementId),
      'kind': serializer.toJson<int>(
        $RegimensTable.$converterkind.toJson(kind),
      ),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'onDays': serializer.toJson<int>(onDays),
      'offDays': serializer.toJson<int>(offDays),
      'paused': serializer.toJson<bool>(paused),
    };
  }

  Regimen copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? supplementId,
    RegimenKind? kind,
    DateTime? startDate,
    Value<DateTime?> endDate = const Value.absent(),
    int? onDays,
    int? offDays,
    bool? paused,
  }) => Regimen(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    supplementId: supplementId ?? this.supplementId,
    kind: kind ?? this.kind,
    startDate: startDate ?? this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    onDays: onDays ?? this.onDays,
    offDays: offDays ?? this.offDays,
    paused: paused ?? this.paused,
  );
  Regimen copyWithCompanion(RegimensCompanion data) {
    return Regimen(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      supplementId: data.supplementId.present
          ? data.supplementId.value
          : this.supplementId,
      kind: data.kind.present ? data.kind.value : this.kind,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      onDays: data.onDays.present ? data.onDays.value : this.onDays,
      offDays: data.offDays.present ? data.offDays.value : this.offDays,
      paused: data.paused.present ? data.paused.value : this.paused,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Regimen(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('supplementId: $supplementId, ')
          ..write('kind: $kind, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('onDays: $onDays, ')
          ..write('offDays: $offDays, ')
          ..write('paused: $paused')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    supplementId,
    kind,
    startDate,
    endDate,
    onDays,
    offDays,
    paused,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Regimen &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.supplementId == this.supplementId &&
          other.kind == this.kind &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.onDays == this.onDays &&
          other.offDays == this.offDays &&
          other.paused == this.paused);
}

class RegimensCompanion extends UpdateCompanion<Regimen> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> supplementId;
  final Value<RegimenKind> kind;
  final Value<DateTime> startDate;
  final Value<DateTime?> endDate;
  final Value<int> onDays;
  final Value<int> offDays;
  final Value<bool> paused;
  final Value<int> rowid;
  const RegimensCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.supplementId = const Value.absent(),
    this.kind = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.onDays = const Value.absent(),
    this.offDays = const Value.absent(),
    this.paused = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RegimensCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    required String supplementId,
    required RegimenKind kind,
    required DateTime startDate,
    this.endDate = const Value.absent(),
    this.onDays = const Value.absent(),
    this.offDays = const Value.absent(),
    this.paused = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       supplementId = Value(supplementId),
       kind = Value(kind),
       startDate = Value(startDate);
  static Insertable<Regimen> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? supplementId,
    Expression<int>? kind,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<int>? onDays,
    Expression<int>? offDays,
    Expression<bool>? paused,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (supplementId != null) 'supplement_id': supplementId,
      if (kind != null) 'kind': kind,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (onDays != null) 'on_days': onDays,
      if (offDays != null) 'off_days': offDays,
      if (paused != null) 'paused': paused,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RegimensCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? supplementId,
    Value<RegimenKind>? kind,
    Value<DateTime>? startDate,
    Value<DateTime?>? endDate,
    Value<int>? onDays,
    Value<int>? offDays,
    Value<bool>? paused,
    Value<int>? rowid,
  }) {
    return RegimensCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      supplementId: supplementId ?? this.supplementId,
      kind: kind ?? this.kind,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      onDays: onDays ?? this.onDays,
      offDays: offDays ?? this.offDays,
      paused: paused ?? this.paused,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (supplementId.present) {
      map['supplement_id'] = Variable<String>(supplementId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(
        $RegimensTable.$converterkind.toSql(kind.value),
      );
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (onDays.present) {
      map['on_days'] = Variable<int>(onDays.value);
    }
    if (offDays.present) {
      map['off_days'] = Variable<int>(offDays.value);
    }
    if (paused.present) {
      map['paused'] = Variable<bool>(paused.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RegimensCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('supplementId: $supplementId, ')
          ..write('kind: $kind, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('onDays: $onDays, ')
          ..write('offDays: $offDays, ')
          ..write('paused: $paused, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RegimenSlotsTable extends RegimenSlots
    with TableInfo<$RegimenSlotsTable, RegimenSlot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RegimenSlotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _regimenIdMeta = const VerificationMeta(
    'regimenId',
  );
  @override
  late final GeneratedColumn<String> regimenId = GeneratedColumn<String>(
    'regimen_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES regimens (id)',
    ),
  );
  static const VerificationMeta _minutesFromMidnightMeta =
      const VerificationMeta('minutesFromMidnight');
  @override
  late final GeneratedColumn<int> minutesFromMidnight = GeneratedColumn<int>(
    'minutes_from_midnight',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _doseLabelMeta = const VerificationMeta(
    'doseLabel',
  );
  @override
  late final GeneratedColumn<String> doseLabel = GeneratedColumn<String>(
    'dose_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    regimenId,
    minutesFromMidnight,
    doseLabel,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'regimen_slots';
  @override
  VerificationContext validateIntegrity(
    Insertable<RegimenSlot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('regimen_id')) {
      context.handle(
        _regimenIdMeta,
        regimenId.isAcceptableOrUnknown(data['regimen_id']!, _regimenIdMeta),
      );
    } else if (isInserting) {
      context.missing(_regimenIdMeta);
    }
    if (data.containsKey('minutes_from_midnight')) {
      context.handle(
        _minutesFromMidnightMeta,
        minutesFromMidnight.isAcceptableOrUnknown(
          data['minutes_from_midnight']!,
          _minutesFromMidnightMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_minutesFromMidnightMeta);
    }
    if (data.containsKey('dose_label')) {
      context.handle(
        _doseLabelMeta,
        doseLabel.isAcceptableOrUnknown(data['dose_label']!, _doseLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_doseLabelMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RegimenSlot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RegimenSlot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      regimenId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}regimen_id'],
      )!,
      minutesFromMidnight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minutes_from_midnight'],
      )!,
      doseLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dose_label'],
      )!,
    );
  }

  @override
  $RegimenSlotsTable createAlias(String alias) {
    return $RegimenSlotsTable(attachedDatabase, alias);
  }
}

class RegimenSlot extends DataClass implements Insertable<RegimenSlot> {
  /// TEXT UUID primary key — generated by repositories via `Uuid().v4()`,
  /// never by the database (no auto-increment, per DATA-02).
  final String id;

  /// True UTC instant of row creation.
  final DateTime createdAt;

  /// True UTC instant of last modification.
  final DateTime updatedAt;

  /// Soft-delete marker: null while the row is live (DATA-02 — no hard
  /// deletes).
  final DateTime? deletedAt;
  final String regimenId;

  /// Wall-clock time of day, minutes since midnight (0..1439).
  final int minutesFromMidnight;
  final String doseLabel;
  const RegimenSlot({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.regimenId,
    required this.minutesFromMidnight,
    required this.doseLabel,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['regimen_id'] = Variable<String>(regimenId);
    map['minutes_from_midnight'] = Variable<int>(minutesFromMidnight);
    map['dose_label'] = Variable<String>(doseLabel);
    return map;
  }

  RegimenSlotsCompanion toCompanion(bool nullToAbsent) {
    return RegimenSlotsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      regimenId: Value(regimenId),
      minutesFromMidnight: Value(minutesFromMidnight),
      doseLabel: Value(doseLabel),
    );
  }

  factory RegimenSlot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RegimenSlot(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      regimenId: serializer.fromJson<String>(json['regimenId']),
      minutesFromMidnight: serializer.fromJson<int>(
        json['minutesFromMidnight'],
      ),
      doseLabel: serializer.fromJson<String>(json['doseLabel']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'regimenId': serializer.toJson<String>(regimenId),
      'minutesFromMidnight': serializer.toJson<int>(minutesFromMidnight),
      'doseLabel': serializer.toJson<String>(doseLabel),
    };
  }

  RegimenSlot copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? regimenId,
    int? minutesFromMidnight,
    String? doseLabel,
  }) => RegimenSlot(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    regimenId: regimenId ?? this.regimenId,
    minutesFromMidnight: minutesFromMidnight ?? this.minutesFromMidnight,
    doseLabel: doseLabel ?? this.doseLabel,
  );
  RegimenSlot copyWithCompanion(RegimenSlotsCompanion data) {
    return RegimenSlot(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      regimenId: data.regimenId.present ? data.regimenId.value : this.regimenId,
      minutesFromMidnight: data.minutesFromMidnight.present
          ? data.minutesFromMidnight.value
          : this.minutesFromMidnight,
      doseLabel: data.doseLabel.present ? data.doseLabel.value : this.doseLabel,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RegimenSlot(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('regimenId: $regimenId, ')
          ..write('minutesFromMidnight: $minutesFromMidnight, ')
          ..write('doseLabel: $doseLabel')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    regimenId,
    minutesFromMidnight,
    doseLabel,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RegimenSlot &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.regimenId == this.regimenId &&
          other.minutesFromMidnight == this.minutesFromMidnight &&
          other.doseLabel == this.doseLabel);
}

class RegimenSlotsCompanion extends UpdateCompanion<RegimenSlot> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> regimenId;
  final Value<int> minutesFromMidnight;
  final Value<String> doseLabel;
  final Value<int> rowid;
  const RegimenSlotsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.regimenId = const Value.absent(),
    this.minutesFromMidnight = const Value.absent(),
    this.doseLabel = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RegimenSlotsCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    required String regimenId,
    required int minutesFromMidnight,
    required String doseLabel,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       regimenId = Value(regimenId),
       minutesFromMidnight = Value(minutesFromMidnight),
       doseLabel = Value(doseLabel);
  static Insertable<RegimenSlot> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? regimenId,
    Expression<int>? minutesFromMidnight,
    Expression<String>? doseLabel,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (regimenId != null) 'regimen_id': regimenId,
      if (minutesFromMidnight != null)
        'minutes_from_midnight': minutesFromMidnight,
      if (doseLabel != null) 'dose_label': doseLabel,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RegimenSlotsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? regimenId,
    Value<int>? minutesFromMidnight,
    Value<String>? doseLabel,
    Value<int>? rowid,
  }) {
    return RegimenSlotsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      regimenId: regimenId ?? this.regimenId,
      minutesFromMidnight: minutesFromMidnight ?? this.minutesFromMidnight,
      doseLabel: doseLabel ?? this.doseLabel,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (regimenId.present) {
      map['regimen_id'] = Variable<String>(regimenId.value);
    }
    if (minutesFromMidnight.present) {
      map['minutes_from_midnight'] = Variable<int>(minutesFromMidnight.value);
    }
    if (doseLabel.present) {
      map['dose_label'] = Variable<String>(doseLabel.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RegimenSlotsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('regimenId: $regimenId, ')
          ..write('minutesFromMidnight: $minutesFromMidnight, ')
          ..write('doseLabel: $doseLabel, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IntakeLogsTable extends IntakeLogs
    with TableInfo<$IntakeLogsTable, IntakeLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IntakeLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _regimenIdMeta = const VerificationMeta(
    'regimenId',
  );
  @override
  late final GeneratedColumn<String> regimenId = GeneratedColumn<String>(
    'regimen_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES regimens (id)',
    ),
  );
  static const VerificationMeta _slotIdMeta = const VerificationMeta('slotId');
  @override
  late final GeneratedColumn<String> slotId = GeneratedColumn<String>(
    'slot_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES regimen_slots (id)',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DoseStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DoseStatus>($IntakeLogsTable.$converterstatus);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    regimenId,
    slotId,
    date,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'intake_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<IntakeLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('regimen_id')) {
      context.handle(
        _regimenIdMeta,
        regimenId.isAcceptableOrUnknown(data['regimen_id']!, _regimenIdMeta),
      );
    } else if (isInserting) {
      context.missing(_regimenIdMeta);
    }
    if (data.containsKey('slot_id')) {
      context.handle(
        _slotIdMeta,
        slotId.isAcceptableOrUnknown(data['slot_id']!, _slotIdMeta),
      );
    } else if (isInserting) {
      context.missing(_slotIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {slotId, date},
  ];
  @override
  IntakeLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IntakeLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      regimenId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}regimen_id'],
      )!,
      slotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      status: $IntakeLogsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
    );
  }

  @override
  $IntakeLogsTable createAlias(String alias) {
    return $IntakeLogsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DoseStatus, int, int> $converterstatus =
      const EnumIndexConverter<DoseStatus>(DoseStatus.values);
}

class IntakeLog extends DataClass implements Insertable<IntakeLog> {
  /// TEXT UUID primary key — generated by repositories via `Uuid().v4()`,
  /// never by the database (no auto-increment, per DATA-02).
  final String id;

  /// True UTC instant of row creation.
  final DateTime createdAt;

  /// True UTC instant of last modification.
  final DateTime updatedAt;

  /// Soft-delete marker: null while the row is live (DATA-02 — no hard
  /// deletes).
  final DateTime? deletedAt;
  final String regimenId;
  final String slotId;

  /// UTC-midnight calendar identity: always `DateTime.utc(y, m, d)`,
  /// never local midnight (D-18).
  final DateTime date;

  /// Stored as [DoseStatus.index] (D-18).
  final DoseStatus status;
  const IntakeLog({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.regimenId,
    required this.slotId,
    required this.date,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['regimen_id'] = Variable<String>(regimenId);
    map['slot_id'] = Variable<String>(slotId);
    map['date'] = Variable<DateTime>(date);
    {
      map['status'] = Variable<int>(
        $IntakeLogsTable.$converterstatus.toSql(status),
      );
    }
    return map;
  }

  IntakeLogsCompanion toCompanion(bool nullToAbsent) {
    return IntakeLogsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      regimenId: Value(regimenId),
      slotId: Value(slotId),
      date: Value(date),
      status: Value(status),
    );
  }

  factory IntakeLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IntakeLog(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      regimenId: serializer.fromJson<String>(json['regimenId']),
      slotId: serializer.fromJson<String>(json['slotId']),
      date: serializer.fromJson<DateTime>(json['date']),
      status: $IntakeLogsTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'regimenId': serializer.toJson<String>(regimenId),
      'slotId': serializer.toJson<String>(slotId),
      'date': serializer.toJson<DateTime>(date),
      'status': serializer.toJson<int>(
        $IntakeLogsTable.$converterstatus.toJson(status),
      ),
    };
  }

  IntakeLog copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? regimenId,
    String? slotId,
    DateTime? date,
    DoseStatus? status,
  }) => IntakeLog(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    regimenId: regimenId ?? this.regimenId,
    slotId: slotId ?? this.slotId,
    date: date ?? this.date,
    status: status ?? this.status,
  );
  IntakeLog copyWithCompanion(IntakeLogsCompanion data) {
    return IntakeLog(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      regimenId: data.regimenId.present ? data.regimenId.value : this.regimenId,
      slotId: data.slotId.present ? data.slotId.value : this.slotId,
      date: data.date.present ? data.date.value : this.date,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IntakeLog(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('regimenId: $regimenId, ')
          ..write('slotId: $slotId, ')
          ..write('date: $date, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    regimenId,
    slotId,
    date,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntakeLog &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.regimenId == this.regimenId &&
          other.slotId == this.slotId &&
          other.date == this.date &&
          other.status == this.status);
}

class IntakeLogsCompanion extends UpdateCompanion<IntakeLog> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> regimenId;
  final Value<String> slotId;
  final Value<DateTime> date;
  final Value<DoseStatus> status;
  final Value<int> rowid;
  const IntakeLogsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.regimenId = const Value.absent(),
    this.slotId = const Value.absent(),
    this.date = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IntakeLogsCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    required String regimenId,
    required String slotId,
    required DateTime date,
    required DoseStatus status,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       regimenId = Value(regimenId),
       slotId = Value(slotId),
       date = Value(date),
       status = Value(status);
  static Insertable<IntakeLog> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? regimenId,
    Expression<String>? slotId,
    Expression<DateTime>? date,
    Expression<int>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (regimenId != null) 'regimen_id': regimenId,
      if (slotId != null) 'slot_id': slotId,
      if (date != null) 'date': date,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IntakeLogsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? regimenId,
    Value<String>? slotId,
    Value<DateTime>? date,
    Value<DoseStatus>? status,
    Value<int>? rowid,
  }) {
    return IntakeLogsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      regimenId: regimenId ?? this.regimenId,
      slotId: slotId ?? this.slotId,
      date: date ?? this.date,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (regimenId.present) {
      map['regimen_id'] = Variable<String>(regimenId.value);
    }
    if (slotId.present) {
      map['slot_id'] = Variable<String>(slotId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $IntakeLogsTable.$converterstatus.toSql(status.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IntakeLogsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('regimenId: $regimenId, ')
          ..write('slotId: $slotId, ')
          ..write('date: $date, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$BoostqueDb extends GeneratedDatabase {
  _$BoostqueDb(QueryExecutor e) : super(e);
  $BoostqueDbManager get managers => $BoostqueDbManager(this);
  late final $SupplementsTable supplements = $SupplementsTable(this);
  late final $RegimensTable regimens = $RegimensTable(this);
  late final $RegimenSlotsTable regimenSlots = $RegimenSlotsTable(this);
  late final $IntakeLogsTable intakeLogs = $IntakeLogsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    supplements,
    regimens,
    regimenSlots,
    intakeLogs,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$SupplementsTableCreateCompanionBuilder =
    SupplementsCompanion Function({
      required String id,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      required String name,
      required String doseText,
      required int colorValue,
      required String note,
      Value<int> rowid,
    });
typedef $$SupplementsTableUpdateCompanionBuilder =
    SupplementsCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> name,
      Value<String> doseText,
      Value<int> colorValue,
      Value<String> note,
      Value<int> rowid,
    });

final class $$SupplementsTableReferences
    extends BaseReferences<_$BoostqueDb, $SupplementsTable, Supplement> {
  $$SupplementsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RegimensTable, List<Regimen>> _regimensRefsTable(
    _$BoostqueDb db,
  ) => MultiTypedResultKey.fromTable(
    db.regimens,
    aliasName: 'supplements__id__regimens__supplement_id',
  );

  $$RegimensTableProcessedTableManager get regimensRefs {
    final manager = $$RegimensTableTableManager(
      $_db,
      $_db.regimens,
    ).filter((f) => f.supplementId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_regimensRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SupplementsTableFilterComposer
    extends Composer<_$BoostqueDb, $SupplementsTable> {
  $$SupplementsTableFilterComposer({
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

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get doseText => $composableBuilder(
    column: $table.doseText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> regimensRefs(
    Expression<bool> Function($$RegimensTableFilterComposer f) f,
  ) {
    final $$RegimensTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.regimens,
      getReferencedColumn: (t) => t.supplementId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RegimensTableFilterComposer(
            $db: $db,
            $table: $db.regimens,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SupplementsTableOrderingComposer
    extends Composer<_$BoostqueDb, $SupplementsTable> {
  $$SupplementsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get doseText => $composableBuilder(
    column: $table.doseText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SupplementsTableAnnotationComposer
    extends Composer<_$BoostqueDb, $SupplementsTable> {
  $$SupplementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get doseText =>
      $composableBuilder(column: $table.doseText, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  Expression<T> regimensRefs<T extends Object>(
    Expression<T> Function($$RegimensTableAnnotationComposer a) f,
  ) {
    final $$RegimensTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.regimens,
      getReferencedColumn: (t) => t.supplementId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RegimensTableAnnotationComposer(
            $db: $db,
            $table: $db.regimens,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SupplementsTableTableManager
    extends
        RootTableManager<
          _$BoostqueDb,
          $SupplementsTable,
          Supplement,
          $$SupplementsTableFilterComposer,
          $$SupplementsTableOrderingComposer,
          $$SupplementsTableAnnotationComposer,
          $$SupplementsTableCreateCompanionBuilder,
          $$SupplementsTableUpdateCompanionBuilder,
          (Supplement, $$SupplementsTableReferences),
          Supplement,
          PrefetchHooks Function({bool regimensRefs})
        > {
  $$SupplementsTableTableManager(_$BoostqueDb db, $SupplementsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SupplementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SupplementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SupplementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> doseText = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SupplementsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                name: name,
                doseText: doseText,
                colorValue: colorValue,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String name,
                required String doseText,
                required int colorValue,
                required String note,
                Value<int> rowid = const Value.absent(),
              }) => SupplementsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                name: name,
                doseText: doseText,
                colorValue: colorValue,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SupplementsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({regimensRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (regimensRefs) db.regimens],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (regimensRefs)
                    await $_getPrefetchedData<
                      Supplement,
                      $SupplementsTable,
                      Regimen
                    >(
                      currentTable: table,
                      referencedTable: $$SupplementsTableReferences
                          ._regimensRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SupplementsTableReferences(
                            db,
                            table,
                            p0,
                          ).regimensRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.supplementId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SupplementsTableProcessedTableManager =
    ProcessedTableManager<
      _$BoostqueDb,
      $SupplementsTable,
      Supplement,
      $$SupplementsTableFilterComposer,
      $$SupplementsTableOrderingComposer,
      $$SupplementsTableAnnotationComposer,
      $$SupplementsTableCreateCompanionBuilder,
      $$SupplementsTableUpdateCompanionBuilder,
      (Supplement, $$SupplementsTableReferences),
      Supplement,
      PrefetchHooks Function({bool regimensRefs})
    >;
typedef $$RegimensTableCreateCompanionBuilder = RegimensCompanion Function({
  required String id,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  required String supplementId,
  required RegimenKind kind,
  required DateTime startDate,
  Value<DateTime?> endDate,
  Value<int> onDays,
  Value<int> offDays,
  Value<bool> paused,
  Value<int> rowid,
});
typedef $$RegimensTableUpdateCompanionBuilder = RegimensCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> supplementId,
  Value<RegimenKind> kind,
  Value<DateTime> startDate,
  Value<DateTime?> endDate,
  Value<int> onDays,
  Value<int> offDays,
  Value<bool> paused,
  Value<int> rowid,
});

final class $$RegimensTableReferences
    extends BaseReferences<_$BoostqueDb, $RegimensTable, Regimen> {
  $$RegimensTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SupplementsTable _supplementIdTable(_$BoostqueDb db) =>
      db.supplements.createAlias('regimens__supplement_id__supplements__id');

  $$SupplementsTableProcessedTableManager get supplementId {
    final $_column = $_itemColumn<String>('supplement_id')!;

    final manager = $$SupplementsTableTableManager(
      $_db,
      $_db.supplements,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_supplementIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RegimenSlotsTable, List<RegimenSlot>>
  _regimenSlotsRefsTable(_$BoostqueDb db) => MultiTypedResultKey.fromTable(
    db.regimenSlots,
    aliasName: 'regimens__id__regimen_slots__regimen_id',
  );

  $$RegimenSlotsTableProcessedTableManager get regimenSlotsRefs {
    final manager = $$RegimenSlotsTableTableManager(
      $_db,
      $_db.regimenSlots,
    ).filter((f) => f.regimenId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_regimenSlotsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$IntakeLogsTable, List<IntakeLog>>
  _intakeLogsRefsTable(_$BoostqueDb db) => MultiTypedResultKey.fromTable(
    db.intakeLogs,
    aliasName: 'regimens__id__intake_logs__regimen_id',
  );

  $$IntakeLogsTableProcessedTableManager get intakeLogsRefs {
    final manager = $$IntakeLogsTableTableManager(
      $_db,
      $_db.intakeLogs,
    ).filter((f) => f.regimenId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_intakeLogsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RegimensTableFilterComposer
    extends Composer<_$BoostqueDb, $RegimensTable> {
  $$RegimensTableFilterComposer({
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

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RegimenKind, RegimenKind, int> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get onDays => $composableBuilder(
    column: $table.onDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offDays => $composableBuilder(
    column: $table.offDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get paused => $composableBuilder(
    column: $table.paused,
    builder: (column) => ColumnFilters(column),
  );

  $$SupplementsTableFilterComposer get supplementId {
    final $$SupplementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplementId,
      referencedTable: $db.supplements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SupplementsTableFilterComposer(
            $db: $db,
            $table: $db.supplements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> regimenSlotsRefs(
    Expression<bool> Function($$RegimenSlotsTableFilterComposer f) f,
  ) {
    final $$RegimenSlotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.regimenSlots,
      getReferencedColumn: (t) => t.regimenId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RegimenSlotsTableFilterComposer(
            $db: $db,
            $table: $db.regimenSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> intakeLogsRefs(
    Expression<bool> Function($$IntakeLogsTableFilterComposer f) f,
  ) {
    final $$IntakeLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.intakeLogs,
      getReferencedColumn: (t) => t.regimenId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IntakeLogsTableFilterComposer(
            $db: $db,
            $table: $db.intakeLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RegimensTableOrderingComposer
    extends Composer<_$BoostqueDb, $RegimensTable> {
  $$RegimensTableOrderingComposer({
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

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get onDays => $composableBuilder(
    column: $table.onDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offDays => $composableBuilder(
    column: $table.offDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get paused => $composableBuilder(
    column: $table.paused,
    builder: (column) => ColumnOrderings(column),
  );

  $$SupplementsTableOrderingComposer get supplementId {
    final $$SupplementsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplementId,
      referencedTable: $db.supplements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SupplementsTableOrderingComposer(
            $db: $db,
            $table: $db.supplements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RegimensTableAnnotationComposer
    extends Composer<_$BoostqueDb, $RegimensTable> {
  $$RegimensTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RegimenKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<int> get onDays =>
      $composableBuilder(column: $table.onDays, builder: (column) => column);

  GeneratedColumn<int> get offDays =>
      $composableBuilder(column: $table.offDays, builder: (column) => column);

  GeneratedColumn<bool> get paused =>
      $composableBuilder(column: $table.paused, builder: (column) => column);

  $$SupplementsTableAnnotationComposer get supplementId {
    final $$SupplementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplementId,
      referencedTable: $db.supplements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SupplementsTableAnnotationComposer(
            $db: $db,
            $table: $db.supplements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> regimenSlotsRefs<T extends Object>(
    Expression<T> Function($$RegimenSlotsTableAnnotationComposer a) f,
  ) {
    final $$RegimenSlotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.regimenSlots,
      getReferencedColumn: (t) => t.regimenId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RegimenSlotsTableAnnotationComposer(
            $db: $db,
            $table: $db.regimenSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> intakeLogsRefs<T extends Object>(
    Expression<T> Function($$IntakeLogsTableAnnotationComposer a) f,
  ) {
    final $$IntakeLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.intakeLogs,
      getReferencedColumn: (t) => t.regimenId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IntakeLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.intakeLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RegimensTableTableManager
    extends
        RootTableManager<
          _$BoostqueDb,
          $RegimensTable,
          Regimen,
          $$RegimensTableFilterComposer,
          $$RegimensTableOrderingComposer,
          $$RegimensTableAnnotationComposer,
          $$RegimensTableCreateCompanionBuilder,
          $$RegimensTableUpdateCompanionBuilder,
          (Regimen, $$RegimensTableReferences),
          Regimen,
          PrefetchHooks Function({
            bool supplementId,
            bool regimenSlotsRefs,
            bool intakeLogsRefs,
          })
        > {
  $$RegimensTableTableManager(_$BoostqueDb db, $RegimensTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RegimensTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RegimensTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RegimensTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> supplementId = const Value.absent(),
                Value<RegimenKind> kind = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<int> onDays = const Value.absent(),
                Value<int> offDays = const Value.absent(),
                Value<bool> paused = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RegimensCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                supplementId: supplementId,
                kind: kind,
                startDate: startDate,
                endDate: endDate,
                onDays: onDays,
                offDays: offDays,
                paused: paused,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String supplementId,
                required RegimenKind kind,
                required DateTime startDate,
                Value<DateTime?> endDate = const Value.absent(),
                Value<int> onDays = const Value.absent(),
                Value<int> offDays = const Value.absent(),
                Value<bool> paused = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RegimensCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                supplementId: supplementId,
                kind: kind,
                startDate: startDate,
                endDate: endDate,
                onDays: onDays,
                offDays: offDays,
                paused: paused,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RegimensTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                supplementId = false,
                regimenSlotsRefs = false,
                intakeLogsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (regimenSlotsRefs) db.regimenSlots,
                    if (intakeLogsRefs) db.intakeLogs,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (supplementId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.supplementId,
                            referencedTable: $$RegimensTableReferences
                                ._supplementIdTable(db),
                            referencedColumn: $$RegimensTableReferences
                                ._supplementIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (regimenSlotsRefs)
                        await $_getPrefetchedData<
                          Regimen,
                          $RegimensTable,
                          RegimenSlot
                        >(
                          currentTable: table,
                          referencedTable: $$RegimensTableReferences
                              ._regimenSlotsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RegimensTableReferences(
                                db,
                                table,
                                p0,
                              ).regimenSlotsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.regimenId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (intakeLogsRefs)
                        await $_getPrefetchedData<
                          Regimen,
                          $RegimensTable,
                          IntakeLog
                        >(
                          currentTable: table,
                          referencedTable: $$RegimensTableReferences
                              ._intakeLogsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RegimensTableReferences(
                                db,
                                table,
                                p0,
                              ).intakeLogsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.regimenId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RegimensTableProcessedTableManager =
    ProcessedTableManager<
      _$BoostqueDb,
      $RegimensTable,
      Regimen,
      $$RegimensTableFilterComposer,
      $$RegimensTableOrderingComposer,
      $$RegimensTableAnnotationComposer,
      $$RegimensTableCreateCompanionBuilder,
      $$RegimensTableUpdateCompanionBuilder,
      (Regimen, $$RegimensTableReferences),
      Regimen,
      PrefetchHooks Function({
        bool supplementId,
        bool regimenSlotsRefs,
        bool intakeLogsRefs,
      })
    >;
typedef $$RegimenSlotsTableCreateCompanionBuilder =
    RegimenSlotsCompanion Function({
      required String id,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      required String regimenId,
      required int minutesFromMidnight,
      required String doseLabel,
      Value<int> rowid,
    });
typedef $$RegimenSlotsTableUpdateCompanionBuilder =
    RegimenSlotsCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> regimenId,
      Value<int> minutesFromMidnight,
      Value<String> doseLabel,
      Value<int> rowid,
    });

final class $$RegimenSlotsTableReferences
    extends BaseReferences<_$BoostqueDb, $RegimenSlotsTable, RegimenSlot> {
  $$RegimenSlotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RegimensTable _regimenIdTable(_$BoostqueDb db) =>
      db.regimens.createAlias('regimen_slots__regimen_id__regimens__id');

  $$RegimensTableProcessedTableManager get regimenId {
    final $_column = $_itemColumn<String>('regimen_id')!;

    final manager = $$RegimensTableTableManager(
      $_db,
      $_db.regimens,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_regimenIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$IntakeLogsTable, List<IntakeLog>>
  _intakeLogsRefsTable(_$BoostqueDb db) => MultiTypedResultKey.fromTable(
    db.intakeLogs,
    aliasName: 'regimen_slots__id__intake_logs__slot_id',
  );

  $$IntakeLogsTableProcessedTableManager get intakeLogsRefs {
    final manager = $$IntakeLogsTableTableManager(
      $_db,
      $_db.intakeLogs,
    ).filter((f) => f.slotId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_intakeLogsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RegimenSlotsTableFilterComposer
    extends Composer<_$BoostqueDb, $RegimenSlotsTable> {
  $$RegimenSlotsTableFilterComposer({
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

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minutesFromMidnight => $composableBuilder(
    column: $table.minutesFromMidnight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get doseLabel => $composableBuilder(
    column: $table.doseLabel,
    builder: (column) => ColumnFilters(column),
  );

  $$RegimensTableFilterComposer get regimenId {
    final $$RegimensTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.regimenId,
      referencedTable: $db.regimens,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RegimensTableFilterComposer(
            $db: $db,
            $table: $db.regimens,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> intakeLogsRefs(
    Expression<bool> Function($$IntakeLogsTableFilterComposer f) f,
  ) {
    final $$IntakeLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.intakeLogs,
      getReferencedColumn: (t) => t.slotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IntakeLogsTableFilterComposer(
            $db: $db,
            $table: $db.intakeLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RegimenSlotsTableOrderingComposer
    extends Composer<_$BoostqueDb, $RegimenSlotsTable> {
  $$RegimenSlotsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minutesFromMidnight => $composableBuilder(
    column: $table.minutesFromMidnight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get doseLabel => $composableBuilder(
    column: $table.doseLabel,
    builder: (column) => ColumnOrderings(column),
  );

  $$RegimensTableOrderingComposer get regimenId {
    final $$RegimensTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.regimenId,
      referencedTable: $db.regimens,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RegimensTableOrderingComposer(
            $db: $db,
            $table: $db.regimens,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RegimenSlotsTableAnnotationComposer
    extends Composer<_$BoostqueDb, $RegimenSlotsTable> {
  $$RegimenSlotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get minutesFromMidnight => $composableBuilder(
    column: $table.minutesFromMidnight,
    builder: (column) => column,
  );

  GeneratedColumn<String> get doseLabel =>
      $composableBuilder(column: $table.doseLabel, builder: (column) => column);

  $$RegimensTableAnnotationComposer get regimenId {
    final $$RegimensTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.regimenId,
      referencedTable: $db.regimens,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RegimensTableAnnotationComposer(
            $db: $db,
            $table: $db.regimens,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> intakeLogsRefs<T extends Object>(
    Expression<T> Function($$IntakeLogsTableAnnotationComposer a) f,
  ) {
    final $$IntakeLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.intakeLogs,
      getReferencedColumn: (t) => t.slotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IntakeLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.intakeLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RegimenSlotsTableTableManager
    extends
        RootTableManager<
          _$BoostqueDb,
          $RegimenSlotsTable,
          RegimenSlot,
          $$RegimenSlotsTableFilterComposer,
          $$RegimenSlotsTableOrderingComposer,
          $$RegimenSlotsTableAnnotationComposer,
          $$RegimenSlotsTableCreateCompanionBuilder,
          $$RegimenSlotsTableUpdateCompanionBuilder,
          (RegimenSlot, $$RegimenSlotsTableReferences),
          RegimenSlot,
          PrefetchHooks Function({bool regimenId, bool intakeLogsRefs})
        > {
  $$RegimenSlotsTableTableManager(_$BoostqueDb db, $RegimenSlotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RegimenSlotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RegimenSlotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RegimenSlotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> regimenId = const Value.absent(),
                Value<int> minutesFromMidnight = const Value.absent(),
                Value<String> doseLabel = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RegimenSlotsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                regimenId: regimenId,
                minutesFromMidnight: minutesFromMidnight,
                doseLabel: doseLabel,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String regimenId,
                required int minutesFromMidnight,
                required String doseLabel,
                Value<int> rowid = const Value.absent(),
              }) => RegimenSlotsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                regimenId: regimenId,
                minutesFromMidnight: minutesFromMidnight,
                doseLabel: doseLabel,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RegimenSlotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({regimenId = false, intakeLogsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (intakeLogsRefs) db.intakeLogs],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (regimenId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.regimenId,
                        referencedTable: $$RegimenSlotsTableReferences
                            ._regimenIdTable(db),
                        referencedColumn: $$RegimenSlotsTableReferences
                            ._regimenIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (intakeLogsRefs)
                    await $_getPrefetchedData<
                      RegimenSlot,
                      $RegimenSlotsTable,
                      IntakeLog
                    >(
                      currentTable: table,
                      referencedTable: $$RegimenSlotsTableReferences
                          ._intakeLogsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$RegimenSlotsTableReferences(
                            db,
                            table,
                            p0,
                          ).intakeLogsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.slotId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RegimenSlotsTableProcessedTableManager =
    ProcessedTableManager<
      _$BoostqueDb,
      $RegimenSlotsTable,
      RegimenSlot,
      $$RegimenSlotsTableFilterComposer,
      $$RegimenSlotsTableOrderingComposer,
      $$RegimenSlotsTableAnnotationComposer,
      $$RegimenSlotsTableCreateCompanionBuilder,
      $$RegimenSlotsTableUpdateCompanionBuilder,
      (RegimenSlot, $$RegimenSlotsTableReferences),
      RegimenSlot,
      PrefetchHooks Function({bool regimenId, bool intakeLogsRefs})
    >;
typedef $$IntakeLogsTableCreateCompanionBuilder = IntakeLogsCompanion Function({
  required String id,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  required String regimenId,
  required String slotId,
  required DateTime date,
  required DoseStatus status,
  Value<int> rowid,
});
typedef $$IntakeLogsTableUpdateCompanionBuilder = IntakeLogsCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> regimenId,
  Value<String> slotId,
  Value<DateTime> date,
  Value<DoseStatus> status,
  Value<int> rowid,
});

final class $$IntakeLogsTableReferences
    extends BaseReferences<_$BoostqueDb, $IntakeLogsTable, IntakeLog> {
  $$IntakeLogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RegimensTable _regimenIdTable(_$BoostqueDb db) =>
      db.regimens.createAlias('intake_logs__regimen_id__regimens__id');

  $$RegimensTableProcessedTableManager get regimenId {
    final $_column = $_itemColumn<String>('regimen_id')!;

    final manager = $$RegimensTableTableManager(
      $_db,
      $_db.regimens,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_regimenIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RegimenSlotsTable _slotIdTable(_$BoostqueDb db) =>
      db.regimenSlots.createAlias('intake_logs__slot_id__regimen_slots__id');

  $$RegimenSlotsTableProcessedTableManager get slotId {
    final $_column = $_itemColumn<String>('slot_id')!;

    final manager = $$RegimenSlotsTableTableManager(
      $_db,
      $_db.regimenSlots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_slotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$IntakeLogsTableFilterComposer
    extends Composer<_$BoostqueDb, $IntakeLogsTable> {
  $$IntakeLogsTableFilterComposer({
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

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DoseStatus, DoseStatus, int> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$RegimensTableFilterComposer get regimenId {
    final $$RegimensTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.regimenId,
      referencedTable: $db.regimens,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RegimensTableFilterComposer(
            $db: $db,
            $table: $db.regimens,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RegimenSlotsTableFilterComposer get slotId {
    final $$RegimenSlotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotId,
      referencedTable: $db.regimenSlots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RegimenSlotsTableFilterComposer(
            $db: $db,
            $table: $db.regimenSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IntakeLogsTableOrderingComposer
    extends Composer<_$BoostqueDb, $IntakeLogsTable> {
  $$IntakeLogsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  $$RegimensTableOrderingComposer get regimenId {
    final $$RegimensTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.regimenId,
      referencedTable: $db.regimens,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RegimensTableOrderingComposer(
            $db: $db,
            $table: $db.regimens,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RegimenSlotsTableOrderingComposer get slotId {
    final $$RegimenSlotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotId,
      referencedTable: $db.regimenSlots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RegimenSlotsTableOrderingComposer(
            $db: $db,
            $table: $db.regimenSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IntakeLogsTableAnnotationComposer
    extends Composer<_$BoostqueDb, $IntakeLogsTable> {
  $$IntakeLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DoseStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  $$RegimensTableAnnotationComposer get regimenId {
    final $$RegimensTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.regimenId,
      referencedTable: $db.regimens,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RegimensTableAnnotationComposer(
            $db: $db,
            $table: $db.regimens,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RegimenSlotsTableAnnotationComposer get slotId {
    final $$RegimenSlotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotId,
      referencedTable: $db.regimenSlots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RegimenSlotsTableAnnotationComposer(
            $db: $db,
            $table: $db.regimenSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IntakeLogsTableTableManager
    extends
        RootTableManager<
          _$BoostqueDb,
          $IntakeLogsTable,
          IntakeLog,
          $$IntakeLogsTableFilterComposer,
          $$IntakeLogsTableOrderingComposer,
          $$IntakeLogsTableAnnotationComposer,
          $$IntakeLogsTableCreateCompanionBuilder,
          $$IntakeLogsTableUpdateCompanionBuilder,
          (IntakeLog, $$IntakeLogsTableReferences),
          IntakeLog,
          PrefetchHooks Function({bool regimenId, bool slotId})
        > {
  $$IntakeLogsTableTableManager(_$BoostqueDb db, $IntakeLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IntakeLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IntakeLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IntakeLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> regimenId = const Value.absent(),
                Value<String> slotId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<DoseStatus> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IntakeLogsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                regimenId: regimenId,
                slotId: slotId,
                date: date,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String regimenId,
                required String slotId,
                required DateTime date,
                required DoseStatus status,
                Value<int> rowid = const Value.absent(),
              }) => IntakeLogsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                regimenId: regimenId,
                slotId: slotId,
                date: date,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$IntakeLogsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({regimenId = false, slotId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (regimenId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.regimenId,
                        referencedTable: $$IntakeLogsTableReferences
                            ._regimenIdTable(db),
                        referencedColumn: $$IntakeLogsTableReferences
                            ._regimenIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (slotId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.slotId,
                        referencedTable: $$IntakeLogsTableReferences
                            ._slotIdTable(db),
                        referencedColumn: $$IntakeLogsTableReferences
                            ._slotIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$IntakeLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$BoostqueDb,
      $IntakeLogsTable,
      IntakeLog,
      $$IntakeLogsTableFilterComposer,
      $$IntakeLogsTableOrderingComposer,
      $$IntakeLogsTableAnnotationComposer,
      $$IntakeLogsTableCreateCompanionBuilder,
      $$IntakeLogsTableUpdateCompanionBuilder,
      (IntakeLog, $$IntakeLogsTableReferences),
      IntakeLog,
      PrefetchHooks Function({bool regimenId, bool slotId})
    >;

class $BoostqueDbManager {
  final _$BoostqueDb _db;
  $BoostqueDbManager(this._db);
  $$SupplementsTableTableManager get supplements =>
      $$SupplementsTableTableManager(_db, _db.supplements);
  $$RegimensTableTableManager get regimens =>
      $$RegimensTableTableManager(_db, _db.regimens);
  $$RegimenSlotsTableTableManager get regimenSlots =>
      $$RegimenSlotsTableTableManager(_db, _db.regimenSlots);
  $$IntakeLogsTableTableManager get intakeLogs =>
      $$IntakeLogsTableTableManager(_db, _db.intakeLogs);
}
