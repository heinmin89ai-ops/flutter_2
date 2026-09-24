// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UsersTable extends Users with TableInfo<$UsersTable, AppUser> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL UNIQUE',
  );
  static const VerificationMeta _pinHashMeta = const VerificationMeta(
    'pinHash',
  );
  @override
  late final GeneratedColumn<String> pinHash = GeneratedColumn<String>(
    'pin_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<UserRole, String> role =
      GeneratedColumn<String>(
        'role',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<UserRole>($UsersTable.$converterrole);
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
    username,
    pinHash,
    role,
    isActive,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppUser> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('pin_hash')) {
      context.handle(
        _pinHashMeta,
        pinHash.isAcceptableOrUnknown(data['pin_hash']!, _pinHashMeta),
      );
    } else if (isInserting) {
      context.missing(_pinHashMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppUser map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppUser(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      pinHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_hash'],
      )!,
      role: $UsersTable.$converterrole.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}role'],
        )!,
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<UserRole, String, String> $converterrole =
      const EnumNameConverter<UserRole>(UserRole.values);
}

class AppUser extends DataClass implements Insertable<AppUser> {
  final int id;

  /// Login handle. Case-insensitive uniqueness so `Nay` and `nay` cannot both
  /// exist and confuse a cashier at the till.
  final String username;

  /// `salt$derivedKey`, PBKDF2-HMAC-SHA256. Never the secret itself.
  final String pinHash;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;
  const AppUser({
    required this.id,
    required this.username,
    required this.pinHash,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['username'] = Variable<String>(username);
    map['pin_hash'] = Variable<String>(pinHash);
    {
      map['role'] = Variable<String>($UsersTable.$converterrole.toSql(role));
    }
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      username: Value(username),
      pinHash: Value(pinHash),
      role: Value(role),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
    );
  }

  factory AppUser.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppUser(
      id: serializer.fromJson<int>(json['id']),
      username: serializer.fromJson<String>(json['username']),
      pinHash: serializer.fromJson<String>(json['pinHash']),
      role: $UsersTable.$converterrole.fromJson(
        serializer.fromJson<String>(json['role']),
      ),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'username': serializer.toJson<String>(username),
      'pinHash': serializer.toJson<String>(pinHash),
      'role': serializer.toJson<String>(
        $UsersTable.$converterrole.toJson(role),
      ),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AppUser copyWith({
    int? id,
    String? username,
    String? pinHash,
    UserRole? role,
    bool? isActive,
    DateTime? createdAt,
  }) => AppUser(
    id: id ?? this.id,
    username: username ?? this.username,
    pinHash: pinHash ?? this.pinHash,
    role: role ?? this.role,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
  );
  AppUser copyWithCompanion(UsersCompanion data) {
    return AppUser(
      id: data.id.present ? data.id.value : this.id,
      username: data.username.present ? data.username.value : this.username,
      pinHash: data.pinHash.present ? data.pinHash.value : this.pinHash,
      role: data.role.present ? data.role.value : this.role,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppUser(')
          ..write('id: $id, ')
          ..write('username: $username, ')
          ..write('pinHash: $pinHash, ')
          ..write('role: $role, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, username, pinHash, role, isActive, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppUser &&
          other.id == this.id &&
          other.username == this.username &&
          other.pinHash == this.pinHash &&
          other.role == this.role &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt);
}

class UsersCompanion extends UpdateCompanion<AppUser> {
  final Value<int> id;
  final Value<String> username;
  final Value<String> pinHash;
  final Value<UserRole> role;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.username = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.role = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  UsersCompanion.insert({
    this.id = const Value.absent(),
    required String username,
    required String pinHash,
    required UserRole role,
    this.isActive = const Value.absent(),
    required DateTime createdAt,
  }) : username = Value(username),
       pinHash = Value(pinHash),
       role = Value(role),
       createdAt = Value(createdAt);
  static Insertable<AppUser> custom({
    Expression<int>? id,
    Expression<String>? username,
    Expression<String>? pinHash,
    Expression<String>? role,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (username != null) 'username': username,
      if (pinHash != null) 'pin_hash': pinHash,
      if (role != null) 'role': role,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  UsersCompanion copyWith({
    Value<int>? id,
    Value<String>? username,
    Value<String>? pinHash,
    Value<UserRole>? role,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
  }) {
    return UsersCompanion(
      id: id ?? this.id,
      username: username ?? this.username,
      pinHash: pinHash ?? this.pinHash,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (pinHash.present) {
      map['pin_hash'] = Variable<String>(pinHash.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(
        $UsersTable.$converterrole.toSql(role.value),
      );
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('username: $username, ')
          ..write('pinHash: $pinHash, ')
          ..write('role: $role, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $LicenseConfigTable extends LicenseConfig
    with TableInfo<$LicenseConfigTable, LicenseConfigData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LicenseConfigTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL CHECK (id = 1)',
  );
  static const VerificationMeta _activationKeyMeta = const VerificationMeta(
    'activationKey',
  );
  @override
  late final GeneratedColumn<String> activationKey = GeneratedColumn<String>(
    'activation_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _featuresDataMeta = const VerificationMeta(
    'featuresData',
  );
  @override
  late final GeneratedColumn<String> featuresData = GeneratedColumn<String>(
    'features_data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activatedAtMeta = const VerificationMeta(
    'activatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> activatedAt = GeneratedColumn<DateTime>(
    'activated_at',
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
    activationKey,
    featuresData,
    activatedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'license_config';
  @override
  VerificationContext validateIntegrity(
    Insertable<LicenseConfigData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('activation_key')) {
      context.handle(
        _activationKeyMeta,
        activationKey.isAcceptableOrUnknown(
          data['activation_key']!,
          _activationKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activationKeyMeta);
    }
    if (data.containsKey('features_data')) {
      context.handle(
        _featuresDataMeta,
        featuresData.isAcceptableOrUnknown(
          data['features_data']!,
          _featuresDataMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_featuresDataMeta);
    }
    if (data.containsKey('activated_at')) {
      context.handle(
        _activatedAtMeta,
        activatedAt.isAcceptableOrUnknown(
          data['activated_at']!,
          _activatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activatedAtMeta);
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
  LicenseConfigData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LicenseConfigData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      activationKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activation_key'],
      )!,
      featuresData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}features_data'],
      )!,
      activatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}activated_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LicenseConfigTable createAlias(String alias) {
    return $LicenseConfigTable(attachedDatabase, alias);
  }
}

class LicenseConfigData extends DataClass
    implements Insertable<LicenseConfigData> {
  final int id;

  /// Raw vendor-issued key, kept verbatim so it can be re-submitted when the
  /// shop moves to a new device.
  final String activationKey;

  /// JSON string of module permissions, e.g.
  /// `{"pos":true,"reports":true,"credit":false}`.
  final String featuresData;
  final DateTime activatedAt;
  final DateTime updatedAt;
  const LicenseConfigData({
    required this.id,
    required this.activationKey,
    required this.featuresData,
    required this.activatedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['activation_key'] = Variable<String>(activationKey);
    map['features_data'] = Variable<String>(featuresData);
    map['activated_at'] = Variable<DateTime>(activatedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LicenseConfigCompanion toCompanion(bool nullToAbsent) {
    return LicenseConfigCompanion(
      id: Value(id),
      activationKey: Value(activationKey),
      featuresData: Value(featuresData),
      activatedAt: Value(activatedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LicenseConfigData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LicenseConfigData(
      id: serializer.fromJson<int>(json['id']),
      activationKey: serializer.fromJson<String>(json['activationKey']),
      featuresData: serializer.fromJson<String>(json['featuresData']),
      activatedAt: serializer.fromJson<DateTime>(json['activatedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'activationKey': serializer.toJson<String>(activationKey),
      'featuresData': serializer.toJson<String>(featuresData),
      'activatedAt': serializer.toJson<DateTime>(activatedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LicenseConfigData copyWith({
    int? id,
    String? activationKey,
    String? featuresData,
    DateTime? activatedAt,
    DateTime? updatedAt,
  }) => LicenseConfigData(
    id: id ?? this.id,
    activationKey: activationKey ?? this.activationKey,
    featuresData: featuresData ?? this.featuresData,
    activatedAt: activatedAt ?? this.activatedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LicenseConfigData copyWithCompanion(LicenseConfigCompanion data) {
    return LicenseConfigData(
      id: data.id.present ? data.id.value : this.id,
      activationKey: data.activationKey.present
          ? data.activationKey.value
          : this.activationKey,
      featuresData: data.featuresData.present
          ? data.featuresData.value
          : this.featuresData,
      activatedAt: data.activatedAt.present
          ? data.activatedAt.value
          : this.activatedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LicenseConfigData(')
          ..write('id: $id, ')
          ..write('activationKey: $activationKey, ')
          ..write('featuresData: $featuresData, ')
          ..write('activatedAt: $activatedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, activationKey, featuresData, activatedAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LicenseConfigData &&
          other.id == this.id &&
          other.activationKey == this.activationKey &&
          other.featuresData == this.featuresData &&
          other.activatedAt == this.activatedAt &&
          other.updatedAt == this.updatedAt);
}

class LicenseConfigCompanion extends UpdateCompanion<LicenseConfigData> {
  final Value<int> id;
  final Value<String> activationKey;
  final Value<String> featuresData;
  final Value<DateTime> activatedAt;
  final Value<DateTime> updatedAt;
  const LicenseConfigCompanion({
    this.id = const Value.absent(),
    this.activationKey = const Value.absent(),
    this.featuresData = const Value.absent(),
    this.activatedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LicenseConfigCompanion.insert({
    this.id = const Value.absent(),
    required String activationKey,
    required String featuresData,
    required DateTime activatedAt,
    required DateTime updatedAt,
  }) : activationKey = Value(activationKey),
       featuresData = Value(featuresData),
       activatedAt = Value(activatedAt),
       updatedAt = Value(updatedAt);
  static Insertable<LicenseConfigData> custom({
    Expression<int>? id,
    Expression<String>? activationKey,
    Expression<String>? featuresData,
    Expression<DateTime>? activatedAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activationKey != null) 'activation_key': activationKey,
      if (featuresData != null) 'features_data': featuresData,
      if (activatedAt != null) 'activated_at': activatedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  LicenseConfigCompanion copyWith({
    Value<int>? id,
    Value<String>? activationKey,
    Value<String>? featuresData,
    Value<DateTime>? activatedAt,
    Value<DateTime>? updatedAt,
  }) {
    return LicenseConfigCompanion(
      id: id ?? this.id,
      activationKey: activationKey ?? this.activationKey,
      featuresData: featuresData ?? this.featuresData,
      activatedAt: activatedAt ?? this.activatedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (activationKey.present) {
      map['activation_key'] = Variable<String>(activationKey.value);
    }
    if (featuresData.present) {
      map['features_data'] = Variable<String>(featuresData.value);
    }
    if (activatedAt.present) {
      map['activated_at'] = Variable<DateTime>(activatedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LicenseConfigCompanion(')
          ..write('id: $id, ')
          ..write('activationKey: $activationKey, ')
          ..write('featuresData: $featuresData, ')
          ..write('activatedAt: $activatedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UsersTable users = $UsersTable(this);
  late final $LicenseConfigTable licenseConfig = $LicenseConfigTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [users, licenseConfig];
}

typedef $$UsersTableCreateCompanionBuilder = UsersCompanion Function({
  Value<int> id,
  required String username,
  required String pinHash,
  required UserRole role,
  Value<bool> isActive,
  required DateTime createdAt,
});
typedef $$UsersTableUpdateCompanionBuilder = UsersCompanion Function({
  Value<int> id,
  Value<String> username,
  Value<String> pinHash,
  Value<UserRole> role,
  Value<bool> isActive,
  Value<DateTime> createdAt,
});

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
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

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<UserRole, UserRole, String> get role =>
      $composableBuilder(
        column: $table.role,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
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

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get pinHash =>
      $composableBuilder(column: $table.pinHash, builder: (column) => column);

  GeneratedColumnWithTypeConverter<UserRole, String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$UsersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsersTable,
          AppUser,
          $$UsersTableFilterComposer,
          $$UsersTableOrderingComposer,
          $$UsersTableAnnotationComposer,
          $$UsersTableCreateCompanionBuilder,
          $$UsersTableUpdateCompanionBuilder,
          (AppUser, BaseReferences<_$AppDatabase, $UsersTable, AppUser>),
          AppUser,
          PrefetchHooks Function()
        > {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<String> pinHash = const Value.absent(),
                Value<UserRole> role = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => UsersCompanion(
                id: id,
                username: username,
                pinHash: pinHash,
                role: role,
                isActive: isActive,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String username,
                required String pinHash,
                required UserRole role,
                Value<bool> isActive = const Value.absent(),
                required DateTime createdAt,
              }) => UsersCompanion.insert(
                id: id,
                username: username,
                pinHash: pinHash,
                role: role,
                isActive: isActive,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UsersTable, AppUser>(table),
                  BaseReferences<_$AppDatabase, $UsersTable, AppUser>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsersTable,
      AppUser,
      $$UsersTableFilterComposer,
      $$UsersTableOrderingComposer,
      $$UsersTableAnnotationComposer,
      $$UsersTableCreateCompanionBuilder,
      $$UsersTableUpdateCompanionBuilder,
      (AppUser, BaseReferences<_$AppDatabase, $UsersTable, AppUser>),
      AppUser,
      PrefetchHooks Function()
    >;
typedef $$LicenseConfigTableCreateCompanionBuilder =
    LicenseConfigCompanion Function({
      Value<int> id,
      required String activationKey,
      required String featuresData,
      required DateTime activatedAt,
      required DateTime updatedAt,
    });
typedef $$LicenseConfigTableUpdateCompanionBuilder =
    LicenseConfigCompanion Function({
      Value<int> id,
      Value<String> activationKey,
      Value<String> featuresData,
      Value<DateTime> activatedAt,
      Value<DateTime> updatedAt,
    });

class $$LicenseConfigTableFilterComposer
    extends Composer<_$AppDatabase, $LicenseConfigTable> {
  $$LicenseConfigTableFilterComposer({
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

  ColumnFilters<String> get activationKey => $composableBuilder(
    column: $table.activationKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get featuresData => $composableBuilder(
    column: $table.featuresData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get activatedAt => $composableBuilder(
    column: $table.activatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LicenseConfigTableOrderingComposer
    extends Composer<_$AppDatabase, $LicenseConfigTable> {
  $$LicenseConfigTableOrderingComposer({
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

  ColumnOrderings<String> get activationKey => $composableBuilder(
    column: $table.activationKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get featuresData => $composableBuilder(
    column: $table.featuresData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get activatedAt => $composableBuilder(
    column: $table.activatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LicenseConfigTableAnnotationComposer
    extends Composer<_$AppDatabase, $LicenseConfigTable> {
  $$LicenseConfigTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get activationKey => $composableBuilder(
    column: $table.activationKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get featuresData => $composableBuilder(
    column: $table.featuresData,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get activatedAt => $composableBuilder(
    column: $table.activatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LicenseConfigTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LicenseConfigTable,
          LicenseConfigData,
          $$LicenseConfigTableFilterComposer,
          $$LicenseConfigTableOrderingComposer,
          $$LicenseConfigTableAnnotationComposer,
          $$LicenseConfigTableCreateCompanionBuilder,
          $$LicenseConfigTableUpdateCompanionBuilder,
          (
            LicenseConfigData,
            BaseReferences<
              _$AppDatabase,
              $LicenseConfigTable,
              LicenseConfigData
            >,
          ),
          LicenseConfigData,
          PrefetchHooks Function()
        > {
  $$LicenseConfigTableTableManager(_$AppDatabase db, $LicenseConfigTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LicenseConfigTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LicenseConfigTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LicenseConfigTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> activationKey = const Value.absent(),
                Value<String> featuresData = const Value.absent(),
                Value<DateTime> activatedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LicenseConfigCompanion(
                id: id,
                activationKey: activationKey,
                featuresData: featuresData,
                activatedAt: activatedAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String activationKey,
                required String featuresData,
                required DateTime activatedAt,
                required DateTime updatedAt,
              }) => LicenseConfigCompanion.insert(
                id: id,
                activationKey: activationKey,
                featuresData: featuresData,
                activatedAt: activatedAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LicenseConfigTable, LicenseConfigData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LicenseConfigTable,
                    LicenseConfigData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LicenseConfigTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LicenseConfigTable,
      LicenseConfigData,
      $$LicenseConfigTableFilterComposer,
      $$LicenseConfigTableOrderingComposer,
      $$LicenseConfigTableAnnotationComposer,
      $$LicenseConfigTableCreateCompanionBuilder,
      $$LicenseConfigTableUpdateCompanionBuilder,
      (
        LicenseConfigData,
        BaseReferences<_$AppDatabase, $LicenseConfigTable, LicenseConfigData>,
      ),
      LicenseConfigData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$LicenseConfigTableTableManager get licenseConfig =>
      $$LicenseConfigTableTableManager(_db, _db.licenseConfig);
}
