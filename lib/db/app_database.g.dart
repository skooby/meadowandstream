// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AssetTagsTable extends AssetTags
    with TableInfo<$AssetTagsTable, AssetTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssetTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _assetIdMeta =
      const VerificationMeta('assetId');
  @override
  late final GeneratedColumn<int> assetId = GeneratedColumn<int>(
      'asset_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _stringIdMeta =
      const VerificationMeta('stringId');
  @override
  late final GeneratedColumn<int> stringId = GeneratedColumn<int>(
      'string_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [assetId, stringId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'asset_tags';
  @override
  VerificationContext validateIntegrity(Insertable<AssetTag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('asset_id')) {
      context.handle(_assetIdMeta,
          assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta));
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('string_id')) {
      context.handle(_stringIdMeta,
          stringId.isAcceptableOrUnknown(data['string_id']!, _stringIdMeta));
    } else if (isInserting) {
      context.missing(_stringIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {assetId, stringId};
  @override
  AssetTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssetTag(
      assetId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}asset_id'])!,
      stringId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}string_id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at']),
    );
  }

  @override
  $AssetTagsTable createAlias(String alias) {
    return $AssetTagsTable(attachedDatabase, alias);
  }
}

class AssetTag extends DataClass implements Insertable<AssetTag> {
  final int assetId;
  final int stringId;
  final int? createdAt;
  const AssetTag(
      {required this.assetId, required this.stringId, this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['asset_id'] = Variable<int>(assetId);
    map['string_id'] = Variable<int>(stringId);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    return map;
  }

  AssetTagsCompanion toCompanion(bool nullToAbsent) {
    return AssetTagsCompanion(
      assetId: Value(assetId),
      stringId: Value(stringId),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory AssetTag.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssetTag(
      assetId: serializer.fromJson<int>(json['assetId']),
      stringId: serializer.fromJson<int>(json['stringId']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'assetId': serializer.toJson<int>(assetId),
      'stringId': serializer.toJson<int>(stringId),
      'createdAt': serializer.toJson<int?>(createdAt),
    };
  }

  AssetTag copyWith(
          {int? assetId,
          int? stringId,
          Value<int?> createdAt = const Value.absent()}) =>
      AssetTag(
        assetId: assetId ?? this.assetId,
        stringId: stringId ?? this.stringId,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
      );
  AssetTag copyWithCompanion(AssetTagsCompanion data) {
    return AssetTag(
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      stringId: data.stringId.present ? data.stringId.value : this.stringId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssetTag(')
          ..write('assetId: $assetId, ')
          ..write('stringId: $stringId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(assetId, stringId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssetTag &&
          other.assetId == this.assetId &&
          other.stringId == this.stringId &&
          other.createdAt == this.createdAt);
}

class AssetTagsCompanion extends UpdateCompanion<AssetTag> {
  final Value<int> assetId;
  final Value<int> stringId;
  final Value<int?> createdAt;
  final Value<int> rowid;
  const AssetTagsCompanion({
    this.assetId = const Value.absent(),
    this.stringId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssetTagsCompanion.insert({
    required int assetId,
    required int stringId,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : assetId = Value(assetId),
        stringId = Value(stringId);
  static Insertable<AssetTag> custom({
    Expression<int>? assetId,
    Expression<int>? stringId,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (assetId != null) 'asset_id': assetId,
      if (stringId != null) 'string_id': stringId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssetTagsCompanion copyWith(
      {Value<int>? assetId,
      Value<int>? stringId,
      Value<int?>? createdAt,
      Value<int>? rowid}) {
    return AssetTagsCompanion(
      assetId: assetId ?? this.assetId,
      stringId: stringId ?? this.stringId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (assetId.present) {
      map['asset_id'] = Variable<int>(assetId.value);
    }
    if (stringId.present) {
      map['string_id'] = Variable<int>(stringId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssetTagsCompanion(')
          ..write('assetId: $assetId, ')
          ..write('stringId: $stringId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AssetRelationsTable extends AssetRelations
    with TableInfo<$AssetRelationsTable, AssetRelation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssetRelationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _primaryAssetIdMeta =
      const VerificationMeta('primaryAssetId');
  @override
  late final GeneratedColumn<int> primaryAssetId = GeneratedColumn<int>(
      'primary_asset_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _relatedAssetIdMeta =
      const VerificationMeta('relatedAssetId');
  @override
  late final GeneratedColumn<int> relatedAssetId = GeneratedColumn<int>(
      'related_asset_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _relationTypeMeta =
      const VerificationMeta('relationType');
  @override
  late final GeneratedColumn<String> relationType = GeneratedColumn<String>(
      'relation_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [primaryAssetId, relatedAssetId, relationType, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'asset_relations';
  @override
  VerificationContext validateIntegrity(Insertable<AssetRelation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('primary_asset_id')) {
      context.handle(
          _primaryAssetIdMeta,
          primaryAssetId.isAcceptableOrUnknown(
              data['primary_asset_id']!, _primaryAssetIdMeta));
    } else if (isInserting) {
      context.missing(_primaryAssetIdMeta);
    }
    if (data.containsKey('related_asset_id')) {
      context.handle(
          _relatedAssetIdMeta,
          relatedAssetId.isAcceptableOrUnknown(
              data['related_asset_id']!, _relatedAssetIdMeta));
    } else if (isInserting) {
      context.missing(_relatedAssetIdMeta);
    }
    if (data.containsKey('relation_type')) {
      context.handle(
          _relationTypeMeta,
          relationType.isAcceptableOrUnknown(
              data['relation_type']!, _relationTypeMeta));
    } else if (isInserting) {
      context.missing(_relationTypeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey =>
      {primaryAssetId, relatedAssetId, relationType};
  @override
  AssetRelation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssetRelation(
      primaryAssetId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}primary_asset_id'])!,
      relatedAssetId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}related_asset_id'])!,
      relationType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}relation_type'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at']),
    );
  }

  @override
  $AssetRelationsTable createAlias(String alias) {
    return $AssetRelationsTable(attachedDatabase, alias);
  }
}

class AssetRelation extends DataClass implements Insertable<AssetRelation> {
  final int primaryAssetId;
  final int relatedAssetId;
  final String relationType;
  final int? createdAt;
  const AssetRelation(
      {required this.primaryAssetId,
      required this.relatedAssetId,
      required this.relationType,
      this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['primary_asset_id'] = Variable<int>(primaryAssetId);
    map['related_asset_id'] = Variable<int>(relatedAssetId);
    map['relation_type'] = Variable<String>(relationType);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    return map;
  }

  AssetRelationsCompanion toCompanion(bool nullToAbsent) {
    return AssetRelationsCompanion(
      primaryAssetId: Value(primaryAssetId),
      relatedAssetId: Value(relatedAssetId),
      relationType: Value(relationType),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory AssetRelation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssetRelation(
      primaryAssetId: serializer.fromJson<int>(json['primaryAssetId']),
      relatedAssetId: serializer.fromJson<int>(json['relatedAssetId']),
      relationType: serializer.fromJson<String>(json['relationType']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'primaryAssetId': serializer.toJson<int>(primaryAssetId),
      'relatedAssetId': serializer.toJson<int>(relatedAssetId),
      'relationType': serializer.toJson<String>(relationType),
      'createdAt': serializer.toJson<int?>(createdAt),
    };
  }

  AssetRelation copyWith(
          {int? primaryAssetId,
          int? relatedAssetId,
          String? relationType,
          Value<int?> createdAt = const Value.absent()}) =>
      AssetRelation(
        primaryAssetId: primaryAssetId ?? this.primaryAssetId,
        relatedAssetId: relatedAssetId ?? this.relatedAssetId,
        relationType: relationType ?? this.relationType,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
      );
  AssetRelation copyWithCompanion(AssetRelationsCompanion data) {
    return AssetRelation(
      primaryAssetId: data.primaryAssetId.present
          ? data.primaryAssetId.value
          : this.primaryAssetId,
      relatedAssetId: data.relatedAssetId.present
          ? data.relatedAssetId.value
          : this.relatedAssetId,
      relationType: data.relationType.present
          ? data.relationType.value
          : this.relationType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssetRelation(')
          ..write('primaryAssetId: $primaryAssetId, ')
          ..write('relatedAssetId: $relatedAssetId, ')
          ..write('relationType: $relationType, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(primaryAssetId, relatedAssetId, relationType, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssetRelation &&
          other.primaryAssetId == this.primaryAssetId &&
          other.relatedAssetId == this.relatedAssetId &&
          other.relationType == this.relationType &&
          other.createdAt == this.createdAt);
}

class AssetRelationsCompanion extends UpdateCompanion<AssetRelation> {
  final Value<int> primaryAssetId;
  final Value<int> relatedAssetId;
  final Value<String> relationType;
  final Value<int?> createdAt;
  final Value<int> rowid;
  const AssetRelationsCompanion({
    this.primaryAssetId = const Value.absent(),
    this.relatedAssetId = const Value.absent(),
    this.relationType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssetRelationsCompanion.insert({
    required int primaryAssetId,
    required int relatedAssetId,
    required String relationType,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : primaryAssetId = Value(primaryAssetId),
        relatedAssetId = Value(relatedAssetId),
        relationType = Value(relationType);
  static Insertable<AssetRelation> custom({
    Expression<int>? primaryAssetId,
    Expression<int>? relatedAssetId,
    Expression<String>? relationType,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (primaryAssetId != null) 'primary_asset_id': primaryAssetId,
      if (relatedAssetId != null) 'related_asset_id': relatedAssetId,
      if (relationType != null) 'relation_type': relationType,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssetRelationsCompanion copyWith(
      {Value<int>? primaryAssetId,
      Value<int>? relatedAssetId,
      Value<String>? relationType,
      Value<int?>? createdAt,
      Value<int>? rowid}) {
    return AssetRelationsCompanion(
      primaryAssetId: primaryAssetId ?? this.primaryAssetId,
      relatedAssetId: relatedAssetId ?? this.relatedAssetId,
      relationType: relationType ?? this.relationType,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (primaryAssetId.present) {
      map['primary_asset_id'] = Variable<int>(primaryAssetId.value);
    }
    if (relatedAssetId.present) {
      map['related_asset_id'] = Variable<int>(relatedAssetId.value);
    }
    if (relationType.present) {
      map['relation_type'] = Variable<String>(relationType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssetRelationsCompanion(')
          ..write('primaryAssetId: $primaryAssetId, ')
          ..write('relatedAssetId: $relatedAssetId, ')
          ..write('relationType: $relationType, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecentPlaysTable extends RecentPlays
    with TableInfo<$RecentPlaysTable, RecentPlay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentPlaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _playedAtMeta =
      const VerificationMeta('playedAt');
  @override
  late final GeneratedColumn<int> playedAt = GeneratedColumn<int>(
      'played_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _collectionIdMeta =
      const VerificationMeta('collectionId');
  @override
  late final GeneratedColumn<String> collectionId = GeneratedColumn<String>(
      'collection_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _collectionTitleMeta =
      const VerificationMeta('collectionTitle');
  @override
  late final GeneratedColumn<String> collectionTitle = GeneratedColumn<String>(
      'collection_title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, itemId, playedAt, collectionId, collectionTitle, title, artist];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recent_plays';
  @override
  VerificationContext validateIntegrity(Insertable<RecentPlay> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('played_at')) {
      context.handle(_playedAtMeta,
          playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta));
    } else if (isInserting) {
      context.missing(_playedAtMeta);
    }
    if (data.containsKey('collection_id')) {
      context.handle(
          _collectionIdMeta,
          collectionId.isAcceptableOrUnknown(
              data['collection_id']!, _collectionIdMeta));
    }
    if (data.containsKey('collection_title')) {
      context.handle(
          _collectionTitleMeta,
          collectionTitle.isAcceptableOrUnknown(
              data['collection_title']!, _collectionTitleMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(_artistMeta,
          artist.isAcceptableOrUnknown(data['artist']!, _artistMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecentPlay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentPlay(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      playedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}played_at'])!,
      collectionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}collection_id']),
      collectionTitle: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}collection_title']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist']),
    );
  }

  @override
  $RecentPlaysTable createAlias(String alias) {
    return $RecentPlaysTable(attachedDatabase, alias);
  }
}

class RecentPlay extends DataClass implements Insertable<RecentPlay> {
  final int id;
  final String itemId;
  final int playedAt;
  final String? collectionId;
  final String? collectionTitle;
  final String title;
  final String? artist;
  const RecentPlay(
      {required this.id,
      required this.itemId,
      required this.playedAt,
      this.collectionId,
      this.collectionTitle,
      required this.title,
      this.artist});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['item_id'] = Variable<String>(itemId);
    map['played_at'] = Variable<int>(playedAt);
    if (!nullToAbsent || collectionId != null) {
      map['collection_id'] = Variable<String>(collectionId);
    }
    if (!nullToAbsent || collectionTitle != null) {
      map['collection_title'] = Variable<String>(collectionTitle);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    return map;
  }

  RecentPlaysCompanion toCompanion(bool nullToAbsent) {
    return RecentPlaysCompanion(
      id: Value(id),
      itemId: Value(itemId),
      playedAt: Value(playedAt),
      collectionId: collectionId == null && nullToAbsent
          ? const Value.absent()
          : Value(collectionId),
      collectionTitle: collectionTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(collectionTitle),
      title: Value(title),
      artist:
          artist == null && nullToAbsent ? const Value.absent() : Value(artist),
    );
  }

  factory RecentPlay.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentPlay(
      id: serializer.fromJson<int>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      playedAt: serializer.fromJson<int>(json['playedAt']),
      collectionId: serializer.fromJson<String?>(json['collectionId']),
      collectionTitle: serializer.fromJson<String?>(json['collectionTitle']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'itemId': serializer.toJson<String>(itemId),
      'playedAt': serializer.toJson<int>(playedAt),
      'collectionId': serializer.toJson<String?>(collectionId),
      'collectionTitle': serializer.toJson<String?>(collectionTitle),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String?>(artist),
    };
  }

  RecentPlay copyWith(
          {int? id,
          String? itemId,
          int? playedAt,
          Value<String?> collectionId = const Value.absent(),
          Value<String?> collectionTitle = const Value.absent(),
          String? title,
          Value<String?> artist = const Value.absent()}) =>
      RecentPlay(
        id: id ?? this.id,
        itemId: itemId ?? this.itemId,
        playedAt: playedAt ?? this.playedAt,
        collectionId:
            collectionId.present ? collectionId.value : this.collectionId,
        collectionTitle: collectionTitle.present
            ? collectionTitle.value
            : this.collectionTitle,
        title: title ?? this.title,
        artist: artist.present ? artist.value : this.artist,
      );
  RecentPlay copyWithCompanion(RecentPlaysCompanion data) {
    return RecentPlay(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
      collectionTitle: data.collectionTitle.present
          ? data.collectionTitle.value
          : this.collectionTitle,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentPlay(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('playedAt: $playedAt, ')
          ..write('collectionId: $collectionId, ')
          ..write('collectionTitle: $collectionTitle, ')
          ..write('title: $title, ')
          ..write('artist: $artist')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, itemId, playedAt, collectionId, collectionTitle, title, artist);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentPlay &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.playedAt == this.playedAt &&
          other.collectionId == this.collectionId &&
          other.collectionTitle == this.collectionTitle &&
          other.title == this.title &&
          other.artist == this.artist);
}

class RecentPlaysCompanion extends UpdateCompanion<RecentPlay> {
  final Value<int> id;
  final Value<String> itemId;
  final Value<int> playedAt;
  final Value<String?> collectionId;
  final Value<String?> collectionTitle;
  final Value<String> title;
  final Value<String?> artist;
  const RecentPlaysCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.playedAt = const Value.absent(),
    this.collectionId = const Value.absent(),
    this.collectionTitle = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
  });
  RecentPlaysCompanion.insert({
    this.id = const Value.absent(),
    required String itemId,
    required int playedAt,
    this.collectionId = const Value.absent(),
    this.collectionTitle = const Value.absent(),
    required String title,
    this.artist = const Value.absent(),
  })  : itemId = Value(itemId),
        playedAt = Value(playedAt),
        title = Value(title);
  static Insertable<RecentPlay> custom({
    Expression<int>? id,
    Expression<String>? itemId,
    Expression<int>? playedAt,
    Expression<String>? collectionId,
    Expression<String>? collectionTitle,
    Expression<String>? title,
    Expression<String>? artist,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (playedAt != null) 'played_at': playedAt,
      if (collectionId != null) 'collection_id': collectionId,
      if (collectionTitle != null) 'collection_title': collectionTitle,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
    });
  }

  RecentPlaysCompanion copyWith(
      {Value<int>? id,
      Value<String>? itemId,
      Value<int>? playedAt,
      Value<String?>? collectionId,
      Value<String?>? collectionTitle,
      Value<String>? title,
      Value<String?>? artist}) {
    return RecentPlaysCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      playedAt: playedAt ?? this.playedAt,
      collectionId: collectionId ?? this.collectionId,
      collectionTitle: collectionTitle ?? this.collectionTitle,
      title: title ?? this.title,
      artist: artist ?? this.artist,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<int>(playedAt.value);
    }
    if (collectionId.present) {
      map['collection_id'] = Variable<String>(collectionId.value);
    }
    if (collectionTitle.present) {
      map['collection_title'] = Variable<String>(collectionTitle.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentPlaysCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('playedAt: $playedAt, ')
          ..write('collectionId: $collectionId, ')
          ..write('collectionTitle: $collectionTitle, ')
          ..write('title: $title, ')
          ..write('artist: $artist')
          ..write(')'))
        .toString();
  }
}

class $PlaybackSessionTable extends PlaybackSession
    with TableInfo<$PlaybackSessionTable, PlaybackSessionData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackSessionTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _currentIndexMeta =
      const VerificationMeta('currentIndex');
  @override
  late final GeneratedColumn<int> currentIndex = GeneratedColumn<int>(
      'current_index', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _positionMsMeta =
      const VerificationMeta('positionMs');
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
      'position_ms', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isShuffledMeta =
      const VerificationMeta('isShuffled');
  @override
  late final GeneratedColumn<int> isShuffled = GeneratedColumn<int>(
      'is_shuffled', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _repeatModeMeta =
      const VerificationMeta('repeatMode');
  @override
  late final GeneratedColumn<int> repeatMode = GeneratedColumn<int>(
      'repeat_mode', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, currentIndex, positionMs, isShuffled, repeatMode, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_session';
  @override
  VerificationContext validateIntegrity(
      Insertable<PlaybackSessionData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('current_index')) {
      context.handle(
          _currentIndexMeta,
          currentIndex.isAcceptableOrUnknown(
              data['current_index']!, _currentIndexMeta));
    }
    if (data.containsKey('position_ms')) {
      context.handle(
          _positionMsMeta,
          positionMs.isAcceptableOrUnknown(
              data['position_ms']!, _positionMsMeta));
    }
    if (data.containsKey('is_shuffled')) {
      context.handle(
          _isShuffledMeta,
          isShuffled.isAcceptableOrUnknown(
              data['is_shuffled']!, _isShuffledMeta));
    }
    if (data.containsKey('repeat_mode')) {
      context.handle(
          _repeatModeMeta,
          repeatMode.isAcceptableOrUnknown(
              data['repeat_mode']!, _repeatModeMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaybackSessionData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackSessionData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      currentIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}current_index'])!,
      positionMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position_ms'])!,
      isShuffled: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}is_shuffled'])!,
      repeatMode: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}repeat_mode'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PlaybackSessionTable createAlias(String alias) {
    return $PlaybackSessionTable(attachedDatabase, alias);
  }
}

class PlaybackSessionData extends DataClass
    implements Insertable<PlaybackSessionData> {
  final int id;
  final int currentIndex;
  final int positionMs;
  final int isShuffled;
  final int repeatMode;
  final int updatedAt;
  const PlaybackSessionData(
      {required this.id,
      required this.currentIndex,
      required this.positionMs,
      required this.isShuffled,
      required this.repeatMode,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['current_index'] = Variable<int>(currentIndex);
    map['position_ms'] = Variable<int>(positionMs);
    map['is_shuffled'] = Variable<int>(isShuffled);
    map['repeat_mode'] = Variable<int>(repeatMode);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  PlaybackSessionCompanion toCompanion(bool nullToAbsent) {
    return PlaybackSessionCompanion(
      id: Value(id),
      currentIndex: Value(currentIndex),
      positionMs: Value(positionMs),
      isShuffled: Value(isShuffled),
      repeatMode: Value(repeatMode),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaybackSessionData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackSessionData(
      id: serializer.fromJson<int>(json['id']),
      currentIndex: serializer.fromJson<int>(json['currentIndex']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      isShuffled: serializer.fromJson<int>(json['isShuffled']),
      repeatMode: serializer.fromJson<int>(json['repeatMode']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'currentIndex': serializer.toJson<int>(currentIndex),
      'positionMs': serializer.toJson<int>(positionMs),
      'isShuffled': serializer.toJson<int>(isShuffled),
      'repeatMode': serializer.toJson<int>(repeatMode),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  PlaybackSessionData copyWith(
          {int? id,
          int? currentIndex,
          int? positionMs,
          int? isShuffled,
          int? repeatMode,
          int? updatedAt}) =>
      PlaybackSessionData(
        id: id ?? this.id,
        currentIndex: currentIndex ?? this.currentIndex,
        positionMs: positionMs ?? this.positionMs,
        isShuffled: isShuffled ?? this.isShuffled,
        repeatMode: repeatMode ?? this.repeatMode,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PlaybackSessionData copyWithCompanion(PlaybackSessionCompanion data) {
    return PlaybackSessionData(
      id: data.id.present ? data.id.value : this.id,
      currentIndex: data.currentIndex.present
          ? data.currentIndex.value
          : this.currentIndex,
      positionMs:
          data.positionMs.present ? data.positionMs.value : this.positionMs,
      isShuffled:
          data.isShuffled.present ? data.isShuffled.value : this.isShuffled,
      repeatMode:
          data.repeatMode.present ? data.repeatMode.value : this.repeatMode,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackSessionData(')
          ..write('id: $id, ')
          ..write('currentIndex: $currentIndex, ')
          ..write('positionMs: $positionMs, ')
          ..write('isShuffled: $isShuffled, ')
          ..write('repeatMode: $repeatMode, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, currentIndex, positionMs, isShuffled, repeatMode, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackSessionData &&
          other.id == this.id &&
          other.currentIndex == this.currentIndex &&
          other.positionMs == this.positionMs &&
          other.isShuffled == this.isShuffled &&
          other.repeatMode == this.repeatMode &&
          other.updatedAt == this.updatedAt);
}

class PlaybackSessionCompanion extends UpdateCompanion<PlaybackSessionData> {
  final Value<int> id;
  final Value<int> currentIndex;
  final Value<int> positionMs;
  final Value<int> isShuffled;
  final Value<int> repeatMode;
  final Value<int> updatedAt;
  const PlaybackSessionCompanion({
    this.id = const Value.absent(),
    this.currentIndex = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.isShuffled = const Value.absent(),
    this.repeatMode = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PlaybackSessionCompanion.insert({
    this.id = const Value.absent(),
    this.currentIndex = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.isShuffled = const Value.absent(),
    this.repeatMode = const Value.absent(),
    required int updatedAt,
  }) : updatedAt = Value(updatedAt);
  static Insertable<PlaybackSessionData> custom({
    Expression<int>? id,
    Expression<int>? currentIndex,
    Expression<int>? positionMs,
    Expression<int>? isShuffled,
    Expression<int>? repeatMode,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (currentIndex != null) 'current_index': currentIndex,
      if (positionMs != null) 'position_ms': positionMs,
      if (isShuffled != null) 'is_shuffled': isShuffled,
      if (repeatMode != null) 'repeat_mode': repeatMode,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PlaybackSessionCompanion copyWith(
      {Value<int>? id,
      Value<int>? currentIndex,
      Value<int>? positionMs,
      Value<int>? isShuffled,
      Value<int>? repeatMode,
      Value<int>? updatedAt}) {
    return PlaybackSessionCompanion(
      id: id ?? this.id,
      currentIndex: currentIndex ?? this.currentIndex,
      positionMs: positionMs ?? this.positionMs,
      isShuffled: isShuffled ?? this.isShuffled,
      repeatMode: repeatMode ?? this.repeatMode,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (currentIndex.present) {
      map['current_index'] = Variable<int>(currentIndex.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (isShuffled.present) {
      map['is_shuffled'] = Variable<int>(isShuffled.value);
    }
    if (repeatMode.present) {
      map['repeat_mode'] = Variable<int>(repeatMode.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackSessionCompanion(')
          ..write('id: $id, ')
          ..write('currentIndex: $currentIndex, ')
          ..write('positionMs: $positionMs, ')
          ..write('isShuffled: $isShuffled, ')
          ..write('repeatMode: $repeatMode, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PlaybackQueueItemsTable extends PlaybackQueueItems
    with TableInfo<$PlaybackQueueItemsTable, PlaybackQueueItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackQueueItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
      'session_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES playback_session (id) ON DELETE CASCADE'));
  static const VerificationMeta _sortIndexMeta =
      const VerificationMeta('sortIndex');
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
      'sort_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _collectionIdMeta =
      const VerificationMeta('collectionId');
  @override
  late final GeneratedColumn<String> collectionId = GeneratedColumn<String>(
      'collection_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [sessionId, sortIndex, itemId, collectionId, title];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_queue_items';
  @override
  VerificationContext validateIntegrity(Insertable<PlaybackQueueItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('sort_index')) {
      context.handle(_sortIndexMeta,
          sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta));
    } else if (isInserting) {
      context.missing(_sortIndexMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('collection_id')) {
      context.handle(
          _collectionIdMeta,
          collectionId.isAcceptableOrUnknown(
              data['collection_id']!, _collectionIdMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId, sortIndex};
  @override
  PlaybackQueueItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackQueueItem(
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}session_id'])!,
      sortIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_index'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      collectionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}collection_id']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title']),
    );
  }

  @override
  $PlaybackQueueItemsTable createAlias(String alias) {
    return $PlaybackQueueItemsTable(attachedDatabase, alias);
  }
}

class PlaybackQueueItem extends DataClass
    implements Insertable<PlaybackQueueItem> {
  final int sessionId;
  final int sortIndex;
  final String itemId;
  final String? collectionId;
  final String? title;
  const PlaybackQueueItem(
      {required this.sessionId,
      required this.sortIndex,
      required this.itemId,
      this.collectionId,
      this.title});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<int>(sessionId);
    map['sort_index'] = Variable<int>(sortIndex);
    map['item_id'] = Variable<String>(itemId);
    if (!nullToAbsent || collectionId != null) {
      map['collection_id'] = Variable<String>(collectionId);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    return map;
  }

  PlaybackQueueItemsCompanion toCompanion(bool nullToAbsent) {
    return PlaybackQueueItemsCompanion(
      sessionId: Value(sessionId),
      sortIndex: Value(sortIndex),
      itemId: Value(itemId),
      collectionId: collectionId == null && nullToAbsent
          ? const Value.absent()
          : Value(collectionId),
      title:
          title == null && nullToAbsent ? const Value.absent() : Value(title),
    );
  }

  factory PlaybackQueueItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackQueueItem(
      sessionId: serializer.fromJson<int>(json['sessionId']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      itemId: serializer.fromJson<String>(json['itemId']),
      collectionId: serializer.fromJson<String?>(json['collectionId']),
      title: serializer.fromJson<String?>(json['title']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<int>(sessionId),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'itemId': serializer.toJson<String>(itemId),
      'collectionId': serializer.toJson<String?>(collectionId),
      'title': serializer.toJson<String?>(title),
    };
  }

  PlaybackQueueItem copyWith(
          {int? sessionId,
          int? sortIndex,
          String? itemId,
          Value<String?> collectionId = const Value.absent(),
          Value<String?> title = const Value.absent()}) =>
      PlaybackQueueItem(
        sessionId: sessionId ?? this.sessionId,
        sortIndex: sortIndex ?? this.sortIndex,
        itemId: itemId ?? this.itemId,
        collectionId:
            collectionId.present ? collectionId.value : this.collectionId,
        title: title.present ? title.value : this.title,
      );
  PlaybackQueueItem copyWithCompanion(PlaybackQueueItemsCompanion data) {
    return PlaybackQueueItem(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
      title: data.title.present ? data.title.value : this.title,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackQueueItem(')
          ..write('sessionId: $sessionId, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('itemId: $itemId, ')
          ..write('collectionId: $collectionId, ')
          ..write('title: $title')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sessionId, sortIndex, itemId, collectionId, title);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackQueueItem &&
          other.sessionId == this.sessionId &&
          other.sortIndex == this.sortIndex &&
          other.itemId == this.itemId &&
          other.collectionId == this.collectionId &&
          other.title == this.title);
}

class PlaybackQueueItemsCompanion extends UpdateCompanion<PlaybackQueueItem> {
  final Value<int> sessionId;
  final Value<int> sortIndex;
  final Value<String> itemId;
  final Value<String?> collectionId;
  final Value<String?> title;
  final Value<int> rowid;
  const PlaybackQueueItemsCompanion({
    this.sessionId = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.itemId = const Value.absent(),
    this.collectionId = const Value.absent(),
    this.title = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaybackQueueItemsCompanion.insert({
    required int sessionId,
    required int sortIndex,
    required String itemId,
    this.collectionId = const Value.absent(),
    this.title = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : sessionId = Value(sessionId),
        sortIndex = Value(sortIndex),
        itemId = Value(itemId);
  static Insertable<PlaybackQueueItem> custom({
    Expression<int>? sessionId,
    Expression<int>? sortIndex,
    Expression<String>? itemId,
    Expression<String>? collectionId,
    Expression<String>? title,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (itemId != null) 'item_id': itemId,
      if (collectionId != null) 'collection_id': collectionId,
      if (title != null) 'title': title,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaybackQueueItemsCompanion copyWith(
      {Value<int>? sessionId,
      Value<int>? sortIndex,
      Value<String>? itemId,
      Value<String?>? collectionId,
      Value<String?>? title,
      Value<int>? rowid}) {
    return PlaybackQueueItemsCompanion(
      sessionId: sessionId ?? this.sessionId,
      sortIndex: sortIndex ?? this.sortIndex,
      itemId: itemId ?? this.itemId,
      collectionId: collectionId ?? this.collectionId,
      title: title ?? this.title,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (collectionId.present) {
      map['collection_id'] = Variable<String>(collectionId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackQueueItemsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('itemId: $itemId, ')
          ..write('collectionId: $collectionId, ')
          ..write('title: $title, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, Playlist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(Insertable<Playlist> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Playlist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Playlist(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class Playlist extends DataClass implements Insertable<Playlist> {
  final String id;
  final String name;
  final int createdAt;
  final int updatedAt;
  const Playlist(
      {required this.id,
      required this.name,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Playlist.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Playlist(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Playlist copyWith(
          {String? id, String? name, int? createdAt, int? updatedAt}) =>
      Playlist(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Playlist copyWithCompanion(PlaylistsCompanion data) {
    return Playlist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Playlist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Playlist &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PlaylistsCompanion extends UpdateCompanion<Playlist> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    required String id,
    required String name,
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Playlist> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<int>? createdAt,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistItemsTable extends PlaylistItems
    with TableInfo<$PlaylistItemsTable, PlaylistItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta =
      const VerificationMeta('playlistId');
  @override
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
      'playlist_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sortIndexMeta =
      const VerificationMeta('sortIndex');
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
      'sort_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [playlistId, sortIndex, itemId, title, artist];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_items';
  @override
  VerificationContext validateIntegrity(Insertable<PlaylistItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
          _playlistIdMeta,
          playlistId.isAcceptableOrUnknown(
              data['playlist_id']!, _playlistIdMeta));
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('sort_index')) {
      context.handle(_sortIndexMeta,
          sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta));
    } else if (isInserting) {
      context.missing(_sortIndexMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('artist')) {
      context.handle(_artistMeta,
          artist.isAcceptableOrUnknown(data['artist']!, _artistMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, sortIndex};
  @override
  PlaylistItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistItem(
      playlistId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}playlist_id'])!,
      sortIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_index'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title']),
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist']),
    );
  }

  @override
  $PlaylistItemsTable createAlias(String alias) {
    return $PlaylistItemsTable(attachedDatabase, alias);
  }
}

class PlaylistItem extends DataClass implements Insertable<PlaylistItem> {
  final String playlistId;
  final int sortIndex;
  final String itemId;
  final String? title;
  final String? artist;
  const PlaylistItem(
      {required this.playlistId,
      required this.sortIndex,
      required this.itemId,
      this.title,
      this.artist});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<String>(playlistId);
    map['sort_index'] = Variable<int>(sortIndex);
    map['item_id'] = Variable<String>(itemId);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    return map;
  }

  PlaylistItemsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistItemsCompanion(
      playlistId: Value(playlistId),
      sortIndex: Value(sortIndex),
      itemId: Value(itemId),
      title:
          title == null && nullToAbsent ? const Value.absent() : Value(title),
      artist:
          artist == null && nullToAbsent ? const Value.absent() : Value(artist),
    );
  }

  factory PlaylistItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistItem(
      playlistId: serializer.fromJson<String>(json['playlistId']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      itemId: serializer.fromJson<String>(json['itemId']),
      title: serializer.fromJson<String?>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<String>(playlistId),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'itemId': serializer.toJson<String>(itemId),
      'title': serializer.toJson<String?>(title),
      'artist': serializer.toJson<String?>(artist),
    };
  }

  PlaylistItem copyWith(
          {String? playlistId,
          int? sortIndex,
          String? itemId,
          Value<String?> title = const Value.absent(),
          Value<String?> artist = const Value.absent()}) =>
      PlaylistItem(
        playlistId: playlistId ?? this.playlistId,
        sortIndex: sortIndex ?? this.sortIndex,
        itemId: itemId ?? this.itemId,
        title: title.present ? title.value : this.title,
        artist: artist.present ? artist.value : this.artist,
      );
  PlaylistItem copyWithCompanion(PlaylistItemsCompanion data) {
    return PlaylistItem(
      playlistId:
          data.playlistId.present ? data.playlistId.value : this.playlistId,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistItem(')
          ..write('playlistId: $playlistId, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('itemId: $itemId, ')
          ..write('title: $title, ')
          ..write('artist: $artist')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playlistId, sortIndex, itemId, title, artist);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistItem &&
          other.playlistId == this.playlistId &&
          other.sortIndex == this.sortIndex &&
          other.itemId == this.itemId &&
          other.title == this.title &&
          other.artist == this.artist);
}

class PlaylistItemsCompanion extends UpdateCompanion<PlaylistItem> {
  final Value<String> playlistId;
  final Value<int> sortIndex;
  final Value<String> itemId;
  final Value<String?> title;
  final Value<String?> artist;
  final Value<int> rowid;
  const PlaylistItemsCompanion({
    this.playlistId = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.itemId = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistItemsCompanion.insert({
    required String playlistId,
    required int sortIndex,
    required String itemId,
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : playlistId = Value(playlistId),
        sortIndex = Value(sortIndex),
        itemId = Value(itemId);
  static Insertable<PlaylistItem> custom({
    Expression<String>? playlistId,
    Expression<int>? sortIndex,
    Expression<String>? itemId,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (itemId != null) 'item_id': itemId,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistItemsCompanion copyWith(
      {Value<String>? playlistId,
      Value<int>? sortIndex,
      Value<String>? itemId,
      Value<String?>? title,
      Value<String?>? artist,
      Value<int>? rowid}) {
    return PlaylistItemsCompanion(
      playlistId: playlistId ?? this.playlistId,
      sortIndex: sortIndex ?? this.sortIndex,
      itemId: itemId ?? this.itemId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistItemsCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('itemId: $itemId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecentSearchesTable extends RecentSearches
    with TableInfo<$RecentSearchesTable, RecentSearch> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentSearchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
      'query', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _searchedAtMeta =
      const VerificationMeta('searchedAt');
  @override
  late final GeneratedColumn<DateTime> searchedAt = GeneratedColumn<DateTime>(
      'searched_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, query, searchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recent_searches';
  @override
  VerificationContext validateIntegrity(Insertable<RecentSearch> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('query')) {
      context.handle(
          _queryMeta, query.isAcceptableOrUnknown(data['query']!, _queryMeta));
    } else if (isInserting) {
      context.missing(_queryMeta);
    }
    if (data.containsKey('searched_at')) {
      context.handle(
          _searchedAtMeta,
          searchedAt.isAcceptableOrUnknown(
              data['searched_at']!, _searchedAtMeta));
    } else if (isInserting) {
      context.missing(_searchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecentSearch map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentSearch(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      query: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}query'])!,
      searchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}searched_at'])!,
    );
  }

  @override
  $RecentSearchesTable createAlias(String alias) {
    return $RecentSearchesTable(attachedDatabase, alias);
  }
}

class RecentSearch extends DataClass implements Insertable<RecentSearch> {
  final int id;
  final String query;
  final DateTime searchedAt;
  const RecentSearch(
      {required this.id, required this.query, required this.searchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['query'] = Variable<String>(query);
    map['searched_at'] = Variable<DateTime>(searchedAt);
    return map;
  }

  RecentSearchesCompanion toCompanion(bool nullToAbsent) {
    return RecentSearchesCompanion(
      id: Value(id),
      query: Value(query),
      searchedAt: Value(searchedAt),
    );
  }

  factory RecentSearch.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentSearch(
      id: serializer.fromJson<int>(json['id']),
      query: serializer.fromJson<String>(json['query']),
      searchedAt: serializer.fromJson<DateTime>(json['searchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'query': serializer.toJson<String>(query),
      'searchedAt': serializer.toJson<DateTime>(searchedAt),
    };
  }

  RecentSearch copyWith({int? id, String? query, DateTime? searchedAt}) =>
      RecentSearch(
        id: id ?? this.id,
        query: query ?? this.query,
        searchedAt: searchedAt ?? this.searchedAt,
      );
  RecentSearch copyWithCompanion(RecentSearchesCompanion data) {
    return RecentSearch(
      id: data.id.present ? data.id.value : this.id,
      query: data.query.present ? data.query.value : this.query,
      searchedAt:
          data.searchedAt.present ? data.searchedAt.value : this.searchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentSearch(')
          ..write('id: $id, ')
          ..write('query: $query, ')
          ..write('searchedAt: $searchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, query, searchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentSearch &&
          other.id == this.id &&
          other.query == this.query &&
          other.searchedAt == this.searchedAt);
}

class RecentSearchesCompanion extends UpdateCompanion<RecentSearch> {
  final Value<int> id;
  final Value<String> query;
  final Value<DateTime> searchedAt;
  const RecentSearchesCompanion({
    this.id = const Value.absent(),
    this.query = const Value.absent(),
    this.searchedAt = const Value.absent(),
  });
  RecentSearchesCompanion.insert({
    this.id = const Value.absent(),
    required String query,
    required DateTime searchedAt,
  })  : query = Value(query),
        searchedAt = Value(searchedAt);
  static Insertable<RecentSearch> custom({
    Expression<int>? id,
    Expression<String>? query,
    Expression<DateTime>? searchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (query != null) 'query': query,
      if (searchedAt != null) 'searched_at': searchedAt,
    });
  }

  RecentSearchesCompanion copyWith(
      {Value<int>? id, Value<String>? query, Value<DateTime>? searchedAt}) {
    return RecentSearchesCompanion(
      id: id ?? this.id,
      query: query ?? this.query,
      searchedAt: searchedAt ?? this.searchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (searchedAt.present) {
      map['searched_at'] = Variable<DateTime>(searchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentSearchesCompanion(')
          ..write('id: $id, ')
          ..write('query: $query, ')
          ..write('searchedAt: $searchedAt')
          ..write(')'))
        .toString();
  }
}

class $FavoritesCollectionsTable extends FavoritesCollections
    with TableInfo<$FavoritesCollectionsTable, FavoriteCollection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesCollectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionIdMeta =
      const VerificationMeta('collectionId');
  @override
  late final GeneratedColumn<String> collectionId = GeneratedColumn<String>(
      'collection_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _favoritedAtMeta =
      const VerificationMeta('favoritedAt');
  @override
  late final GeneratedColumn<DateTime> favoritedAt = GeneratedColumn<DateTime>(
      'favorited_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [collectionId, favoritedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites_collections';
  @override
  VerificationContext validateIntegrity(Insertable<FavoriteCollection> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection_id')) {
      context.handle(
          _collectionIdMeta,
          collectionId.isAcceptableOrUnknown(
              data['collection_id']!, _collectionIdMeta));
    } else if (isInserting) {
      context.missing(_collectionIdMeta);
    }
    if (data.containsKey('favorited_at')) {
      context.handle(
          _favoritedAtMeta,
          favoritedAt.isAcceptableOrUnknown(
              data['favorited_at']!, _favoritedAtMeta));
    } else if (isInserting) {
      context.missing(_favoritedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collectionId};
  @override
  FavoriteCollection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteCollection(
      collectionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}collection_id'])!,
      favoritedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}favorited_at'])!,
    );
  }

  @override
  $FavoritesCollectionsTable createAlias(String alias) {
    return $FavoritesCollectionsTable(attachedDatabase, alias);
  }
}

class FavoriteCollection extends DataClass
    implements Insertable<FavoriteCollection> {
  final String collectionId;
  final DateTime favoritedAt;
  const FavoriteCollection(
      {required this.collectionId, required this.favoritedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection_id'] = Variable<String>(collectionId);
    map['favorited_at'] = Variable<DateTime>(favoritedAt);
    return map;
  }

  FavoritesCollectionsCompanion toCompanion(bool nullToAbsent) {
    return FavoritesCollectionsCompanion(
      collectionId: Value(collectionId),
      favoritedAt: Value(favoritedAt),
    );
  }

  factory FavoriteCollection.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteCollection(
      collectionId: serializer.fromJson<String>(json['collectionId']),
      favoritedAt: serializer.fromJson<DateTime>(json['favoritedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collectionId': serializer.toJson<String>(collectionId),
      'favoritedAt': serializer.toJson<DateTime>(favoritedAt),
    };
  }

  FavoriteCollection copyWith({String? collectionId, DateTime? favoritedAt}) =>
      FavoriteCollection(
        collectionId: collectionId ?? this.collectionId,
        favoritedAt: favoritedAt ?? this.favoritedAt,
      );
  FavoriteCollection copyWithCompanion(FavoritesCollectionsCompanion data) {
    return FavoriteCollection(
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
      favoritedAt:
          data.favoritedAt.present ? data.favoritedAt.value : this.favoritedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteCollection(')
          ..write('collectionId: $collectionId, ')
          ..write('favoritedAt: $favoritedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collectionId, favoritedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteCollection &&
          other.collectionId == this.collectionId &&
          other.favoritedAt == this.favoritedAt);
}

class FavoritesCollectionsCompanion
    extends UpdateCompanion<FavoriteCollection> {
  final Value<String> collectionId;
  final Value<DateTime> favoritedAt;
  final Value<int> rowid;
  const FavoritesCollectionsCompanion({
    this.collectionId = const Value.absent(),
    this.favoritedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoritesCollectionsCompanion.insert({
    required String collectionId,
    required DateTime favoritedAt,
    this.rowid = const Value.absent(),
  })  : collectionId = Value(collectionId),
        favoritedAt = Value(favoritedAt);
  static Insertable<FavoriteCollection> custom({
    Expression<String>? collectionId,
    Expression<DateTime>? favoritedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collectionId != null) 'collection_id': collectionId,
      if (favoritedAt != null) 'favorited_at': favoritedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoritesCollectionsCompanion copyWith(
      {Value<String>? collectionId,
      Value<DateTime>? favoritedAt,
      Value<int>? rowid}) {
    return FavoritesCollectionsCompanion(
      collectionId: collectionId ?? this.collectionId,
      favoritedAt: favoritedAt ?? this.favoritedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collectionId.present) {
      map['collection_id'] = Variable<String>(collectionId.value);
    }
    if (favoritedAt.present) {
      map['favorited_at'] = Variable<DateTime>(favoritedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesCollectionsCompanion(')
          ..write('collectionId: $collectionId, ')
          ..write('favoritedAt: $favoritedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoritesItemsTable extends FavoritesItems
    with TableInfo<$FavoritesItemsTable, FavoriteItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _favoritedAtMeta =
      const VerificationMeta('favoritedAt');
  @override
  late final GeneratedColumn<DateTime> favoritedAt = GeneratedColumn<DateTime>(
      'favorited_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [itemId, favoritedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites_items';
  @override
  VerificationContext validateIntegrity(Insertable<FavoriteItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('favorited_at')) {
      context.handle(
          _favoritedAtMeta,
          favoritedAt.isAcceptableOrUnknown(
              data['favorited_at']!, _favoritedAtMeta));
    } else if (isInserting) {
      context.missing(_favoritedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  FavoriteItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteItem(
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      favoritedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}favorited_at'])!,
    );
  }

  @override
  $FavoritesItemsTable createAlias(String alias) {
    return $FavoritesItemsTable(attachedDatabase, alias);
  }
}

class FavoriteItem extends DataClass implements Insertable<FavoriteItem> {
  final String itemId;
  final DateTime favoritedAt;
  const FavoriteItem({required this.itemId, required this.favoritedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['favorited_at'] = Variable<DateTime>(favoritedAt);
    return map;
  }

  FavoritesItemsCompanion toCompanion(bool nullToAbsent) {
    return FavoritesItemsCompanion(
      itemId: Value(itemId),
      favoritedAt: Value(favoritedAt),
    );
  }

  factory FavoriteItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteItem(
      itemId: serializer.fromJson<String>(json['itemId']),
      favoritedAt: serializer.fromJson<DateTime>(json['favoritedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'favoritedAt': serializer.toJson<DateTime>(favoritedAt),
    };
  }

  FavoriteItem copyWith({String? itemId, DateTime? favoritedAt}) =>
      FavoriteItem(
        itemId: itemId ?? this.itemId,
        favoritedAt: favoritedAt ?? this.favoritedAt,
      );
  FavoriteItem copyWithCompanion(FavoritesItemsCompanion data) {
    return FavoriteItem(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      favoritedAt:
          data.favoritedAt.present ? data.favoritedAt.value : this.favoritedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteItem(')
          ..write('itemId: $itemId, ')
          ..write('favoritedAt: $favoritedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, favoritedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteItem &&
          other.itemId == this.itemId &&
          other.favoritedAt == this.favoritedAt);
}

class FavoritesItemsCompanion extends UpdateCompanion<FavoriteItem> {
  final Value<String> itemId;
  final Value<DateTime> favoritedAt;
  final Value<int> rowid;
  const FavoritesItemsCompanion({
    this.itemId = const Value.absent(),
    this.favoritedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoritesItemsCompanion.insert({
    required String itemId,
    required DateTime favoritedAt,
    this.rowid = const Value.absent(),
  })  : itemId = Value(itemId),
        favoritedAt = Value(favoritedAt);
  static Insertable<FavoriteItem> custom({
    Expression<String>? itemId,
    Expression<DateTime>? favoritedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (favoritedAt != null) 'favorited_at': favoritedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoritesItemsCompanion copyWith(
      {Value<String>? itemId,
      Value<DateTime>? favoritedAt,
      Value<int>? rowid}) {
    return FavoritesItemsCompanion(
      itemId: itemId ?? this.itemId,
      favoritedAt: favoritedAt ?? this.favoritedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (favoritedAt.present) {
      map['favorited_at'] = Variable<DateTime>(favoritedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesItemsCompanion(')
          ..write('itemId: $itemId, ')
          ..write('favoritedAt: $favoritedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AudioCacheTable extends AudioCache
    with TableInfo<$AudioCacheTable, AudioCacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudioCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
      'status', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _localPathMeta =
      const VerificationMeta('localPath');
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
      'local_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fileBytesMeta =
      const VerificationMeta('fileBytes');
  @override
  late final GeneratedColumn<int> fileBytes = GeneratedColumn<int>(
      'file_bytes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _lastAccessedAtMeta =
      const VerificationMeta('lastAccessedAt');
  @override
  late final GeneratedColumn<int> lastAccessedAt = GeneratedColumn<int>(
      'last_accessed_at', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastPlayedAtMeta =
      const VerificationMeta('lastPlayedAt');
  @override
  late final GeneratedColumn<int> lastPlayedAt = GeneratedColumn<int>(
      'last_played_at', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _cacheScoreMeta =
      const VerificationMeta('cacheScore');
  @override
  late final GeneratedColumn<double> cacheScore = GeneratedColumn<double>(
      'cache_score', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
      'error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        itemId,
        status,
        localPath,
        fileBytes,
        lastAccessedAt,
        lastPlayedAt,
        cacheScore,
        error,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audio_cache';
  @override
  VerificationContext validateIntegrity(Insertable<AudioCacheEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(_localPathMeta,
          localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta));
    }
    if (data.containsKey('file_bytes')) {
      context.handle(_fileBytesMeta,
          fileBytes.isAcceptableOrUnknown(data['file_bytes']!, _fileBytesMeta));
    }
    if (data.containsKey('last_accessed_at')) {
      context.handle(
          _lastAccessedAtMeta,
          lastAccessedAt.isAcceptableOrUnknown(
              data['last_accessed_at']!, _lastAccessedAtMeta));
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
          _lastPlayedAtMeta,
          lastPlayedAt.isAcceptableOrUnknown(
              data['last_played_at']!, _lastPlayedAtMeta));
    }
    if (data.containsKey('cache_score')) {
      context.handle(
          _cacheScoreMeta,
          cacheScore.isAcceptableOrUnknown(
              data['cache_score']!, _cacheScoreMeta));
    }
    if (data.containsKey('error')) {
      context.handle(
          _errorMeta, error.isAcceptableOrUnknown(data['error']!, _errorMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  AudioCacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AudioCacheEntry(
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!,
      localPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_path']),
      fileBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}file_bytes']),
      lastAccessedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_accessed_at'])!,
      lastPlayedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_played_at'])!,
      cacheScore: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}cache_score'])!,
      error: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $AudioCacheTable createAlias(String alias) {
    return $AudioCacheTable(attachedDatabase, alias);
  }
}

class AudioCacheEntry extends DataClass implements Insertable<AudioCacheEntry> {
  final String itemId;
  final int status;
  final String? localPath;
  final int? fileBytes;
  final int lastAccessedAt;
  final int lastPlayedAt;
  final double cacheScore;
  final String? error;
  final int updatedAt;
  const AudioCacheEntry(
      {required this.itemId,
      required this.status,
      this.localPath,
      this.fileBytes,
      required this.lastAccessedAt,
      required this.lastPlayedAt,
      required this.cacheScore,
      this.error,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['status'] = Variable<int>(status);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || fileBytes != null) {
      map['file_bytes'] = Variable<int>(fileBytes);
    }
    map['last_accessed_at'] = Variable<int>(lastAccessedAt);
    map['last_played_at'] = Variable<int>(lastPlayedAt);
    map['cache_score'] = Variable<double>(cacheScore);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  AudioCacheCompanion toCompanion(bool nullToAbsent) {
    return AudioCacheCompanion(
      itemId: Value(itemId),
      status: Value(status),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      fileBytes: fileBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(fileBytes),
      lastAccessedAt: Value(lastAccessedAt),
      lastPlayedAt: Value(lastPlayedAt),
      cacheScore: Value(cacheScore),
      error:
          error == null && nullToAbsent ? const Value.absent() : Value(error),
      updatedAt: Value(updatedAt),
    );
  }

  factory AudioCacheEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AudioCacheEntry(
      itemId: serializer.fromJson<String>(json['itemId']),
      status: serializer.fromJson<int>(json['status']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      fileBytes: serializer.fromJson<int?>(json['fileBytes']),
      lastAccessedAt: serializer.fromJson<int>(json['lastAccessedAt']),
      lastPlayedAt: serializer.fromJson<int>(json['lastPlayedAt']),
      cacheScore: serializer.fromJson<double>(json['cacheScore']),
      error: serializer.fromJson<String?>(json['error']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'status': serializer.toJson<int>(status),
      'localPath': serializer.toJson<String?>(localPath),
      'fileBytes': serializer.toJson<int?>(fileBytes),
      'lastAccessedAt': serializer.toJson<int>(lastAccessedAt),
      'lastPlayedAt': serializer.toJson<int>(lastPlayedAt),
      'cacheScore': serializer.toJson<double>(cacheScore),
      'error': serializer.toJson<String?>(error),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  AudioCacheEntry copyWith(
          {String? itemId,
          int? status,
          Value<String?> localPath = const Value.absent(),
          Value<int?> fileBytes = const Value.absent(),
          int? lastAccessedAt,
          int? lastPlayedAt,
          double? cacheScore,
          Value<String?> error = const Value.absent(),
          int? updatedAt}) =>
      AudioCacheEntry(
        itemId: itemId ?? this.itemId,
        status: status ?? this.status,
        localPath: localPath.present ? localPath.value : this.localPath,
        fileBytes: fileBytes.present ? fileBytes.value : this.fileBytes,
        lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
        lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
        cacheScore: cacheScore ?? this.cacheScore,
        error: error.present ? error.value : this.error,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AudioCacheEntry copyWithCompanion(AudioCacheCompanion data) {
    return AudioCacheEntry(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      status: data.status.present ? data.status.value : this.status,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      fileBytes: data.fileBytes.present ? data.fileBytes.value : this.fileBytes,
      lastAccessedAt: data.lastAccessedAt.present
          ? data.lastAccessedAt.value
          : this.lastAccessedAt,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
      cacheScore:
          data.cacheScore.present ? data.cacheScore.value : this.cacheScore,
      error: data.error.present ? data.error.value : this.error,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AudioCacheEntry(')
          ..write('itemId: $itemId, ')
          ..write('status: $status, ')
          ..write('localPath: $localPath, ')
          ..write('fileBytes: $fileBytes, ')
          ..write('lastAccessedAt: $lastAccessedAt, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('cacheScore: $cacheScore, ')
          ..write('error: $error, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, status, localPath, fileBytes,
      lastAccessedAt, lastPlayedAt, cacheScore, error, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioCacheEntry &&
          other.itemId == this.itemId &&
          other.status == this.status &&
          other.localPath == this.localPath &&
          other.fileBytes == this.fileBytes &&
          other.lastAccessedAt == this.lastAccessedAt &&
          other.lastPlayedAt == this.lastPlayedAt &&
          other.cacheScore == this.cacheScore &&
          other.error == this.error &&
          other.updatedAt == this.updatedAt);
}

class AudioCacheCompanion extends UpdateCompanion<AudioCacheEntry> {
  final Value<String> itemId;
  final Value<int> status;
  final Value<String?> localPath;
  final Value<int?> fileBytes;
  final Value<int> lastAccessedAt;
  final Value<int> lastPlayedAt;
  final Value<double> cacheScore;
  final Value<String?> error;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const AudioCacheCompanion({
    this.itemId = const Value.absent(),
    this.status = const Value.absent(),
    this.localPath = const Value.absent(),
    this.fileBytes = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.cacheScore = const Value.absent(),
    this.error = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudioCacheCompanion.insert({
    required String itemId,
    required int status,
    this.localPath = const Value.absent(),
    this.fileBytes = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.cacheScore = const Value.absent(),
    this.error = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : itemId = Value(itemId),
        status = Value(status),
        updatedAt = Value(updatedAt);
  static Insertable<AudioCacheEntry> custom({
    Expression<String>? itemId,
    Expression<int>? status,
    Expression<String>? localPath,
    Expression<int>? fileBytes,
    Expression<int>? lastAccessedAt,
    Expression<int>? lastPlayedAt,
    Expression<double>? cacheScore,
    Expression<String>? error,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (status != null) 'status': status,
      if (localPath != null) 'local_path': localPath,
      if (fileBytes != null) 'file_bytes': fileBytes,
      if (lastAccessedAt != null) 'last_accessed_at': lastAccessedAt,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (cacheScore != null) 'cache_score': cacheScore,
      if (error != null) 'error': error,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AudioCacheCompanion copyWith(
      {Value<String>? itemId,
      Value<int>? status,
      Value<String?>? localPath,
      Value<int?>? fileBytes,
      Value<int>? lastAccessedAt,
      Value<int>? lastPlayedAt,
      Value<double>? cacheScore,
      Value<String?>? error,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return AudioCacheCompanion(
      itemId: itemId ?? this.itemId,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
      fileBytes: fileBytes ?? this.fileBytes,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      cacheScore: cacheScore ?? this.cacheScore,
      error: error ?? this.error,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (fileBytes.present) {
      map['file_bytes'] = Variable<int>(fileBytes.value);
    }
    if (lastAccessedAt.present) {
      map['last_accessed_at'] = Variable<int>(lastAccessedAt.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<int>(lastPlayedAt.value);
    }
    if (cacheScore.present) {
      map['cache_score'] = Variable<double>(cacheScore.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudioCacheCompanion(')
          ..write('itemId: $itemId, ')
          ..write('status: $status, ')
          ..write('localPath: $localPath, ')
          ..write('fileBytes: $fileBytes, ')
          ..write('lastAccessedAt: $lastAccessedAt, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('cacheScore: $cacheScore, ')
          ..write('error: $error, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StringsTable extends Strings
    with TableInfo<$StringsTable, SystemString> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StringsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _tenantIdMeta =
      const VerificationMeta('tenantId');
  @override
  late final GeneratedColumn<int> tenantId = GeneratedColumn<int>(
      'tenant_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<int> parentId = GeneratedColumn<int>(
      'parent_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES strings (id)'));
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('STRING'));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _parameterMeta =
      const VerificationMeta('parameter');
  @override
  late final GeneratedColumn<String> parameter = GeneratedColumn<String>(
      'parameter', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        tenantId,
        key,
        description,
        parentId,
        type,
        sortOrder,
        color,
        parameter,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'strings';
  @override
  VerificationContext validateIntegrity(Insertable<SystemString> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tenant_id')) {
      context.handle(_tenantIdMeta,
          tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta));
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    if (data.containsKey('parameter')) {
      context.handle(_parameterMeta,
          parameter.isAcceptableOrUnknown(data['parameter']!, _parameterMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SystemString map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SystemString(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      tenantId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tenant_id'])!,
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}parent_id']),
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color']),
      parameter: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parameter']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $StringsTable createAlias(String alias) {
    return $StringsTable(attachedDatabase, alias);
  }
}

class SystemString extends DataClass implements Insertable<SystemString> {
  final int id;
  final int tenantId;
  final String key;
  final String? description;
  final int? parentId;
  final String type;
  final int sortOrder;
  final String? color;
  final String? parameter;
  final int? createdAt;
  final int? updatedAt;
  const SystemString(
      {required this.id,
      required this.tenantId,
      required this.key,
      this.description,
      this.parentId,
      required this.type,
      required this.sortOrder,
      this.color,
      this.parameter,
      this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tenant_id'] = Variable<int>(tenantId);
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<int>(parentId);
    }
    map['type'] = Variable<String>(type);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    if (!nullToAbsent || parameter != null) {
      map['parameter'] = Variable<String>(parameter);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<int>(updatedAt);
    }
    return map;
  }

  StringsCompanion toCompanion(bool nullToAbsent) {
    return StringsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      key: Value(key),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      type: Value(type),
      sortOrder: Value(sortOrder),
      color:
          color == null && nullToAbsent ? const Value.absent() : Value(color),
      parameter: parameter == null && nullToAbsent
          ? const Value.absent()
          : Value(parameter),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory SystemString.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SystemString(
      id: serializer.fromJson<int>(json['id']),
      tenantId: serializer.fromJson<int>(json['tenantId']),
      key: serializer.fromJson<String>(json['key']),
      description: serializer.fromJson<String?>(json['description']),
      parentId: serializer.fromJson<int?>(json['parentId']),
      type: serializer.fromJson<String>(json['type']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      color: serializer.fromJson<String?>(json['color']),
      parameter: serializer.fromJson<String?>(json['parameter']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
      updatedAt: serializer.fromJson<int?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tenantId': serializer.toJson<int>(tenantId),
      'key': serializer.toJson<String>(key),
      'description': serializer.toJson<String?>(description),
      'parentId': serializer.toJson<int?>(parentId),
      'type': serializer.toJson<String>(type),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'color': serializer.toJson<String?>(color),
      'parameter': serializer.toJson<String?>(parameter),
      'createdAt': serializer.toJson<int?>(createdAt),
      'updatedAt': serializer.toJson<int?>(updatedAt),
    };
  }

  SystemString copyWith(
          {int? id,
          int? tenantId,
          String? key,
          Value<String?> description = const Value.absent(),
          Value<int?> parentId = const Value.absent(),
          String? type,
          int? sortOrder,
          Value<String?> color = const Value.absent(),
          Value<String?> parameter = const Value.absent(),
          Value<int?> createdAt = const Value.absent(),
          Value<int?> updatedAt = const Value.absent()}) =>
      SystemString(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        key: key ?? this.key,
        description: description.present ? description.value : this.description,
        parentId: parentId.present ? parentId.value : this.parentId,
        type: type ?? this.type,
        sortOrder: sortOrder ?? this.sortOrder,
        color: color.present ? color.value : this.color,
        parameter: parameter.present ? parameter.value : this.parameter,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  SystemString copyWithCompanion(StringsCompanion data) {
    return SystemString(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      key: data.key.present ? data.key.value : this.key,
      description:
          data.description.present ? data.description.value : this.description,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      type: data.type.present ? data.type.value : this.type,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      color: data.color.present ? data.color.value : this.color,
      parameter: data.parameter.present ? data.parameter.value : this.parameter,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SystemString(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('key: $key, ')
          ..write('description: $description, ')
          ..write('parentId: $parentId, ')
          ..write('type: $type, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('color: $color, ')
          ..write('parameter: $parameter, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tenantId, key, description, parentId,
      type, sortOrder, color, parameter, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SystemString &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.key == this.key &&
          other.description == this.description &&
          other.parentId == this.parentId &&
          other.type == this.type &&
          other.sortOrder == this.sortOrder &&
          other.color == this.color &&
          other.parameter == this.parameter &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StringsCompanion extends UpdateCompanion<SystemString> {
  final Value<int> id;
  final Value<int> tenantId;
  final Value<String> key;
  final Value<String?> description;
  final Value<int?> parentId;
  final Value<String> type;
  final Value<int> sortOrder;
  final Value<String?> color;
  final Value<String?> parameter;
  final Value<int?> createdAt;
  final Value<int?> updatedAt;
  const StringsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.key = const Value.absent(),
    this.description = const Value.absent(),
    this.parentId = const Value.absent(),
    this.type = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.color = const Value.absent(),
    this.parameter = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  StringsCompanion.insert({
    this.id = const Value.absent(),
    required int tenantId,
    required String key,
    this.description = const Value.absent(),
    this.parentId = const Value.absent(),
    this.type = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.color = const Value.absent(),
    this.parameter = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : tenantId = Value(tenantId),
        key = Value(key);
  static Insertable<SystemString> custom({
    Expression<int>? id,
    Expression<int>? tenantId,
    Expression<String>? key,
    Expression<String>? description,
    Expression<int>? parentId,
    Expression<String>? type,
    Expression<int>? sortOrder,
    Expression<String>? color,
    Expression<String>? parameter,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (key != null) 'key': key,
      if (description != null) 'description': description,
      if (parentId != null) 'parent_id': parentId,
      if (type != null) 'type': type,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (color != null) 'color': color,
      if (parameter != null) 'parameter': parameter,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  StringsCompanion copyWith(
      {Value<int>? id,
      Value<int>? tenantId,
      Value<String>? key,
      Value<String?>? description,
      Value<int?>? parentId,
      Value<String>? type,
      Value<int>? sortOrder,
      Value<String?>? color,
      Value<String?>? parameter,
      Value<int?>? createdAt,
      Value<int?>? updatedAt}) {
    return StringsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      key: key ?? this.key,
      description: description ?? this.description,
      parentId: parentId ?? this.parentId,
      type: type ?? this.type,
      sortOrder: sortOrder ?? this.sortOrder,
      color: color ?? this.color,
      parameter: parameter ?? this.parameter,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<int>(tenantId.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<int>(parentId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (parameter.present) {
      map['parameter'] = Variable<String>(parameter.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StringsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('key: $key, ')
          ..write('description: $description, ')
          ..write('parentId: $parentId, ')
          ..write('type: $type, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('color: $color, ')
          ..write('parameter: $parameter, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $LanguagesTable extends Languages
    with TableInfo<$LanguagesTable, SystemLanguage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LanguagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _nameStringIdMeta =
      const VerificationMeta('nameStringId');
  @override
  late final GeneratedColumn<int> nameStringId = GeneratedColumn<int>(
      'name_string_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES strings (id)'));
  @override
  List<GeneratedColumn> get $columns => [id, code, nameStringId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'languages';
  @override
  VerificationContext validateIntegrity(Insertable<SystemLanguage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name_string_id')) {
      context.handle(
          _nameStringIdMeta,
          nameStringId.isAcceptableOrUnknown(
              data['name_string_id']!, _nameStringIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SystemLanguage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SystemLanguage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      nameStringId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}name_string_id']),
    );
  }

  @override
  $LanguagesTable createAlias(String alias) {
    return $LanguagesTable(attachedDatabase, alias);
  }
}

class SystemLanguage extends DataClass implements Insertable<SystemLanguage> {
  final int id;
  final String code;
  final int? nameStringId;
  const SystemLanguage(
      {required this.id, required this.code, this.nameStringId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['code'] = Variable<String>(code);
    if (!nullToAbsent || nameStringId != null) {
      map['name_string_id'] = Variable<int>(nameStringId);
    }
    return map;
  }

  LanguagesCompanion toCompanion(bool nullToAbsent) {
    return LanguagesCompanion(
      id: Value(id),
      code: Value(code),
      nameStringId: nameStringId == null && nullToAbsent
          ? const Value.absent()
          : Value(nameStringId),
    );
  }

  factory SystemLanguage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SystemLanguage(
      id: serializer.fromJson<int>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      nameStringId: serializer.fromJson<int?>(json['nameStringId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'code': serializer.toJson<String>(code),
      'nameStringId': serializer.toJson<int?>(nameStringId),
    };
  }

  SystemLanguage copyWith(
          {int? id,
          String? code,
          Value<int?> nameStringId = const Value.absent()}) =>
      SystemLanguage(
        id: id ?? this.id,
        code: code ?? this.code,
        nameStringId:
            nameStringId.present ? nameStringId.value : this.nameStringId,
      );
  SystemLanguage copyWithCompanion(LanguagesCompanion data) {
    return SystemLanguage(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      nameStringId: data.nameStringId.present
          ? data.nameStringId.value
          : this.nameStringId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SystemLanguage(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('nameStringId: $nameStringId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, code, nameStringId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SystemLanguage &&
          other.id == this.id &&
          other.code == this.code &&
          other.nameStringId == this.nameStringId);
}

class LanguagesCompanion extends UpdateCompanion<SystemLanguage> {
  final Value<int> id;
  final Value<String> code;
  final Value<int?> nameStringId;
  const LanguagesCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.nameStringId = const Value.absent(),
  });
  LanguagesCompanion.insert({
    this.id = const Value.absent(),
    required String code,
    this.nameStringId = const Value.absent(),
  }) : code = Value(code);
  static Insertable<SystemLanguage> custom({
    Expression<int>? id,
    Expression<String>? code,
    Expression<int>? nameStringId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (nameStringId != null) 'name_string_id': nameStringId,
    });
  }

  LanguagesCompanion copyWith(
      {Value<int>? id, Value<String>? code, Value<int?>? nameStringId}) {
    return LanguagesCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      nameStringId: nameStringId ?? this.nameStringId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (nameStringId.present) {
      map['name_string_id'] = Variable<int>(nameStringId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LanguagesCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('nameStringId: $nameStringId')
          ..write(')'))
        .toString();
  }
}

class $TranslationsTable extends Translations
    with TableInfo<$TranslationsTable, SystemTranslation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranslationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _tenantIdMeta =
      const VerificationMeta('tenantId');
  @override
  late final GeneratedColumn<int> tenantId = GeneratedColumn<int>(
      'tenant_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _stringIdMeta =
      const VerificationMeta('stringId');
  @override
  late final GeneratedColumn<int> stringId = GeneratedColumn<int>(
      'string_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES strings (id)'));
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _langIdMeta = const VerificationMeta('langId');
  @override
  late final GeneratedColumn<int> langId = GeneratedColumn<int>(
      'lang_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES languages (id)'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, tenantId, stringId, value, langId, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'translations';
  @override
  VerificationContext validateIntegrity(Insertable<SystemTranslation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tenant_id')) {
      context.handle(_tenantIdMeta,
          tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta));
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('string_id')) {
      context.handle(_stringIdMeta,
          stringId.isAcceptableOrUnknown(data['string_id']!, _stringIdMeta));
    } else if (isInserting) {
      context.missing(_stringIdMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('lang_id')) {
      context.handle(_langIdMeta,
          langId.isAcceptableOrUnknown(data['lang_id']!, _langIdMeta));
    } else if (isInserting) {
      context.missing(_langIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SystemTranslation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SystemTranslation(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      tenantId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tenant_id'])!,
      stringId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}string_id'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      langId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}lang_id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $TranslationsTable createAlias(String alias) {
    return $TranslationsTable(attachedDatabase, alias);
  }
}

class SystemTranslation extends DataClass
    implements Insertable<SystemTranslation> {
  final int id;
  final int tenantId;
  final int stringId;
  final String value;
  final int langId;
  final int? createdAt;
  final int? updatedAt;
  const SystemTranslation(
      {required this.id,
      required this.tenantId,
      required this.stringId,
      required this.value,
      required this.langId,
      this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tenant_id'] = Variable<int>(tenantId);
    map['string_id'] = Variable<int>(stringId);
    map['value'] = Variable<String>(value);
    map['lang_id'] = Variable<int>(langId);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<int>(updatedAt);
    }
    return map;
  }

  TranslationsCompanion toCompanion(bool nullToAbsent) {
    return TranslationsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      stringId: Value(stringId),
      value: Value(value),
      langId: Value(langId),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory SystemTranslation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SystemTranslation(
      id: serializer.fromJson<int>(json['id']),
      tenantId: serializer.fromJson<int>(json['tenantId']),
      stringId: serializer.fromJson<int>(json['stringId']),
      value: serializer.fromJson<String>(json['value']),
      langId: serializer.fromJson<int>(json['langId']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
      updatedAt: serializer.fromJson<int?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tenantId': serializer.toJson<int>(tenantId),
      'stringId': serializer.toJson<int>(stringId),
      'value': serializer.toJson<String>(value),
      'langId': serializer.toJson<int>(langId),
      'createdAt': serializer.toJson<int?>(createdAt),
      'updatedAt': serializer.toJson<int?>(updatedAt),
    };
  }

  SystemTranslation copyWith(
          {int? id,
          int? tenantId,
          int? stringId,
          String? value,
          int? langId,
          Value<int?> createdAt = const Value.absent(),
          Value<int?> updatedAt = const Value.absent()}) =>
      SystemTranslation(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        stringId: stringId ?? this.stringId,
        value: value ?? this.value,
        langId: langId ?? this.langId,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  SystemTranslation copyWithCompanion(TranslationsCompanion data) {
    return SystemTranslation(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      stringId: data.stringId.present ? data.stringId.value : this.stringId,
      value: data.value.present ? data.value.value : this.value,
      langId: data.langId.present ? data.langId.value : this.langId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SystemTranslation(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('stringId: $stringId, ')
          ..write('value: $value, ')
          ..write('langId: $langId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, tenantId, stringId, value, langId, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SystemTranslation &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.stringId == this.stringId &&
          other.value == this.value &&
          other.langId == this.langId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TranslationsCompanion extends UpdateCompanion<SystemTranslation> {
  final Value<int> id;
  final Value<int> tenantId;
  final Value<int> stringId;
  final Value<String> value;
  final Value<int> langId;
  final Value<int?> createdAt;
  final Value<int?> updatedAt;
  const TranslationsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.stringId = const Value.absent(),
    this.value = const Value.absent(),
    this.langId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TranslationsCompanion.insert({
    this.id = const Value.absent(),
    required int tenantId,
    required int stringId,
    required String value,
    required int langId,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : tenantId = Value(tenantId),
        stringId = Value(stringId),
        value = Value(value),
        langId = Value(langId);
  static Insertable<SystemTranslation> custom({
    Expression<int>? id,
    Expression<int>? tenantId,
    Expression<int>? stringId,
    Expression<String>? value,
    Expression<int>? langId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (stringId != null) 'string_id': stringId,
      if (value != null) 'value': value,
      if (langId != null) 'lang_id': langId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TranslationsCompanion copyWith(
      {Value<int>? id,
      Value<int>? tenantId,
      Value<int>? stringId,
      Value<String>? value,
      Value<int>? langId,
      Value<int?>? createdAt,
      Value<int?>? updatedAt}) {
    return TranslationsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      stringId: stringId ?? this.stringId,
      value: value ?? this.value,
      langId: langId ?? this.langId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<int>(tenantId.value);
    }
    if (stringId.present) {
      map['string_id'] = Variable<int>(stringId.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (langId.present) {
      map['lang_id'] = Variable<int>(langId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranslationsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('stringId: $stringId, ')
          ..write('value: $value, ')
          ..write('langId: $langId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AssetsTable extends Assets with TableInfo<$AssetsTable, Asset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _tenantIdMeta =
      const VerificationMeta('tenantId');
  @override
  late final GeneratedColumn<int> tenantId = GeneratedColumn<int>(
      'tenant_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<int> parentId = GeneratedColumn<int>(
      'parent_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mimeTypeMeta =
      const VerificationMeta('mimeType');
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
      'mime_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _storagePathMeta =
      const VerificationMeta('storagePath');
  @override
  late final GeneratedColumn<String> storagePath = GeneratedColumn<String>(
      'storage_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sizeBytesMeta =
      const VerificationMeta('sizeBytes');
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
      'size_bytes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _mappedStringFolderIdMeta =
      const VerificationMeta('mappedStringFolderId');
  @override
  late final GeneratedColumn<int> mappedStringFolderId = GeneratedColumn<int>(
      'mapped_string_folder_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _titleStringIdMeta =
      const VerificationMeta('titleStringId');
  @override
  late final GeneratedColumn<int> titleStringId = GeneratedColumn<int>(
      'title_string_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _collectionTypeMeta =
      const VerificationMeta('collectionType');
  @override
  late final GeneratedColumn<String> collectionType = GeneratedColumn<String>(
      'collection_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _searchKeywordsMeta =
      const VerificationMeta('searchKeywords');
  @override
  late final GeneratedColumn<String> searchKeywords = GeneratedColumn<String>(
      'search_keywords', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _relatedAssetIdsMeta =
      const VerificationMeta('relatedAssetIds');
  @override
  late final GeneratedColumn<String> relatedAssetIds = GeneratedColumn<String>(
      'related_asset_ids', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _alternateVersionIdsMeta =
      const VerificationMeta('alternateVersionIds');
  @override
  late final GeneratedColumn<String> alternateVersionIds =
      GeneratedColumn<String>('alternate_version_ids', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        tenantId,
        parentId,
        type,
        mimeType,
        name,
        storagePath,
        sizeBytes,
        mappedStringFolderId,
        description,
        createdAt,
        updatedAt,
        sortOrder,
        titleStringId,
        collectionType,
        searchKeywords,
        relatedAssetIds,
        alternateVersionIds
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assets';
  @override
  VerificationContext validateIntegrity(Insertable<Asset> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tenant_id')) {
      context.handle(_tenantIdMeta,
          tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta));
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(_mimeTypeMeta,
          mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('storage_path')) {
      context.handle(
          _storagePathMeta,
          storagePath.isAcceptableOrUnknown(
              data['storage_path']!, _storagePathMeta));
    }
    if (data.containsKey('size_bytes')) {
      context.handle(_sizeBytesMeta,
          sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta));
    }
    if (data.containsKey('mapped_string_folder_id')) {
      context.handle(
          _mappedStringFolderIdMeta,
          mappedStringFolderId.isAcceptableOrUnknown(
              data['mapped_string_folder_id']!, _mappedStringFolderIdMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('title_string_id')) {
      context.handle(
          _titleStringIdMeta,
          titleStringId.isAcceptableOrUnknown(
              data['title_string_id']!, _titleStringIdMeta));
    }
    if (data.containsKey('collection_type')) {
      context.handle(
          _collectionTypeMeta,
          collectionType.isAcceptableOrUnknown(
              data['collection_type']!, _collectionTypeMeta));
    }
    if (data.containsKey('search_keywords')) {
      context.handle(
          _searchKeywordsMeta,
          searchKeywords.isAcceptableOrUnknown(
              data['search_keywords']!, _searchKeywordsMeta));
    }
    if (data.containsKey('related_asset_ids')) {
      context.handle(
          _relatedAssetIdsMeta,
          relatedAssetIds.isAcceptableOrUnknown(
              data['related_asset_ids']!, _relatedAssetIdsMeta));
    }
    if (data.containsKey('alternate_version_ids')) {
      context.handle(
          _alternateVersionIdsMeta,
          alternateVersionIds.isAcceptableOrUnknown(
              data['alternate_version_ids']!, _alternateVersionIdsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Asset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Asset(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      tenantId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tenant_id'])!,
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}parent_id']),
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      mimeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mime_type']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      storagePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}storage_path']),
      sizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size_bytes']),
      mappedStringFolderId: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}mapped_string_folder_id']),
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order']),
      titleStringId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}title_string_id']),
      collectionType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}collection_type']),
      searchKeywords: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}search_keywords']),
      relatedAssetIds: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}related_asset_ids']),
      alternateVersionIds: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}alternate_version_ids']),
    );
  }

  @override
  $AssetsTable createAlias(String alias) {
    return $AssetsTable(attachedDatabase, alias);
  }
}

class Asset extends DataClass implements Insertable<Asset> {
  final int id;
  final int tenantId;
  final int? parentId;
  final String type;
  final String? mimeType;
  final String name;
  final String? storagePath;
  final int? sizeBytes;
  final int? mappedStringFolderId;
  final String? description;
  final int? createdAt;
  final int? updatedAt;
  final int? sortOrder;
  final int? titleStringId;
  final String? collectionType;
  final String? searchKeywords;
  final String? relatedAssetIds;
  final String? alternateVersionIds;
  const Asset(
      {required this.id,
      required this.tenantId,
      this.parentId,
      required this.type,
      this.mimeType,
      required this.name,
      this.storagePath,
      this.sizeBytes,
      this.mappedStringFolderId,
      this.description,
      this.createdAt,
      this.updatedAt,
      this.sortOrder,
      this.titleStringId,
      this.collectionType,
      this.searchKeywords,
      this.relatedAssetIds,
      this.alternateVersionIds});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tenant_id'] = Variable<int>(tenantId);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<int>(parentId);
    }
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || storagePath != null) {
      map['storage_path'] = Variable<String>(storagePath);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    if (!nullToAbsent || mappedStringFolderId != null) {
      map['mapped_string_folder_id'] = Variable<int>(mappedStringFolderId);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<int>(updatedAt);
    }
    if (!nullToAbsent || sortOrder != null) {
      map['sort_order'] = Variable<int>(sortOrder);
    }
    if (!nullToAbsent || titleStringId != null) {
      map['title_string_id'] = Variable<int>(titleStringId);
    }
    if (!nullToAbsent || collectionType != null) {
      map['collection_type'] = Variable<String>(collectionType);
    }
    if (!nullToAbsent || searchKeywords != null) {
      map['search_keywords'] = Variable<String>(searchKeywords);
    }
    if (!nullToAbsent || relatedAssetIds != null) {
      map['related_asset_ids'] = Variable<String>(relatedAssetIds);
    }
    if (!nullToAbsent || alternateVersionIds != null) {
      map['alternate_version_ids'] = Variable<String>(alternateVersionIds);
    }
    return map;
  }

  AssetsCompanion toCompanion(bool nullToAbsent) {
    return AssetsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      type: Value(type),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      name: Value(name),
      storagePath: storagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(storagePath),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      mappedStringFolderId: mappedStringFolderId == null && nullToAbsent
          ? const Value.absent()
          : Value(mappedStringFolderId),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      sortOrder: sortOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(sortOrder),
      titleStringId: titleStringId == null && nullToAbsent
          ? const Value.absent()
          : Value(titleStringId),
      collectionType: collectionType == null && nullToAbsent
          ? const Value.absent()
          : Value(collectionType),
      searchKeywords: searchKeywords == null && nullToAbsent
          ? const Value.absent()
          : Value(searchKeywords),
      relatedAssetIds: relatedAssetIds == null && nullToAbsent
          ? const Value.absent()
          : Value(relatedAssetIds),
      alternateVersionIds: alternateVersionIds == null && nullToAbsent
          ? const Value.absent()
          : Value(alternateVersionIds),
    );
  }

  factory Asset.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Asset(
      id: serializer.fromJson<int>(json['id']),
      tenantId: serializer.fromJson<int>(json['tenantId']),
      parentId: serializer.fromJson<int?>(json['parentId']),
      type: serializer.fromJson<String>(json['type']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      name: serializer.fromJson<String>(json['name']),
      storagePath: serializer.fromJson<String?>(json['storagePath']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      mappedStringFolderId:
          serializer.fromJson<int?>(json['mappedStringFolderId']),
      description: serializer.fromJson<String?>(json['description']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
      updatedAt: serializer.fromJson<int?>(json['updatedAt']),
      sortOrder: serializer.fromJson<int?>(json['sortOrder']),
      titleStringId: serializer.fromJson<int?>(json['titleStringId']),
      collectionType: serializer.fromJson<String?>(json['collectionType']),
      searchKeywords: serializer.fromJson<String?>(json['searchKeywords']),
      relatedAssetIds: serializer.fromJson<String?>(json['relatedAssetIds']),
      alternateVersionIds:
          serializer.fromJson<String?>(json['alternateVersionIds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tenantId': serializer.toJson<int>(tenantId),
      'parentId': serializer.toJson<int?>(parentId),
      'type': serializer.toJson<String>(type),
      'mimeType': serializer.toJson<String?>(mimeType),
      'name': serializer.toJson<String>(name),
      'storagePath': serializer.toJson<String?>(storagePath),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'mappedStringFolderId': serializer.toJson<int?>(mappedStringFolderId),
      'description': serializer.toJson<String?>(description),
      'createdAt': serializer.toJson<int?>(createdAt),
      'updatedAt': serializer.toJson<int?>(updatedAt),
      'sortOrder': serializer.toJson<int?>(sortOrder),
      'titleStringId': serializer.toJson<int?>(titleStringId),
      'collectionType': serializer.toJson<String?>(collectionType),
      'searchKeywords': serializer.toJson<String?>(searchKeywords),
      'relatedAssetIds': serializer.toJson<String?>(relatedAssetIds),
      'alternateVersionIds': serializer.toJson<String?>(alternateVersionIds),
    };
  }

  Asset copyWith(
          {int? id,
          int? tenantId,
          Value<int?> parentId = const Value.absent(),
          String? type,
          Value<String?> mimeType = const Value.absent(),
          String? name,
          Value<String?> storagePath = const Value.absent(),
          Value<int?> sizeBytes = const Value.absent(),
          Value<int?> mappedStringFolderId = const Value.absent(),
          Value<String?> description = const Value.absent(),
          Value<int?> createdAt = const Value.absent(),
          Value<int?> updatedAt = const Value.absent(),
          Value<int?> sortOrder = const Value.absent(),
          Value<int?> titleStringId = const Value.absent(),
          Value<String?> collectionType = const Value.absent(),
          Value<String?> searchKeywords = const Value.absent(),
          Value<String?> relatedAssetIds = const Value.absent(),
          Value<String?> alternateVersionIds = const Value.absent()}) =>
      Asset(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        parentId: parentId.present ? parentId.value : this.parentId,
        type: type ?? this.type,
        mimeType: mimeType.present ? mimeType.value : this.mimeType,
        name: name ?? this.name,
        storagePath: storagePath.present ? storagePath.value : this.storagePath,
        sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
        mappedStringFolderId: mappedStringFolderId.present
            ? mappedStringFolderId.value
            : this.mappedStringFolderId,
        description: description.present ? description.value : this.description,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
        sortOrder: sortOrder.present ? sortOrder.value : this.sortOrder,
        titleStringId:
            titleStringId.present ? titleStringId.value : this.titleStringId,
        collectionType:
            collectionType.present ? collectionType.value : this.collectionType,
        searchKeywords:
            searchKeywords.present ? searchKeywords.value : this.searchKeywords,
        relatedAssetIds: relatedAssetIds.present
            ? relatedAssetIds.value
            : this.relatedAssetIds,
        alternateVersionIds: alternateVersionIds.present
            ? alternateVersionIds.value
            : this.alternateVersionIds,
      );
  Asset copyWithCompanion(AssetsCompanion data) {
    return Asset(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      type: data.type.present ? data.type.value : this.type,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      name: data.name.present ? data.name.value : this.name,
      storagePath:
          data.storagePath.present ? data.storagePath.value : this.storagePath,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      mappedStringFolderId: data.mappedStringFolderId.present
          ? data.mappedStringFolderId.value
          : this.mappedStringFolderId,
      description:
          data.description.present ? data.description.value : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      titleStringId: data.titleStringId.present
          ? data.titleStringId.value
          : this.titleStringId,
      collectionType: data.collectionType.present
          ? data.collectionType.value
          : this.collectionType,
      searchKeywords: data.searchKeywords.present
          ? data.searchKeywords.value
          : this.searchKeywords,
      relatedAssetIds: data.relatedAssetIds.present
          ? data.relatedAssetIds.value
          : this.relatedAssetIds,
      alternateVersionIds: data.alternateVersionIds.present
          ? data.alternateVersionIds.value
          : this.alternateVersionIds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Asset(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('parentId: $parentId, ')
          ..write('type: $type, ')
          ..write('mimeType: $mimeType, ')
          ..write('name: $name, ')
          ..write('storagePath: $storagePath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('mappedStringFolderId: $mappedStringFolderId, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('titleStringId: $titleStringId, ')
          ..write('collectionType: $collectionType, ')
          ..write('searchKeywords: $searchKeywords, ')
          ..write('relatedAssetIds: $relatedAssetIds, ')
          ..write('alternateVersionIds: $alternateVersionIds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      tenantId,
      parentId,
      type,
      mimeType,
      name,
      storagePath,
      sizeBytes,
      mappedStringFolderId,
      description,
      createdAt,
      updatedAt,
      sortOrder,
      titleStringId,
      collectionType,
      searchKeywords,
      relatedAssetIds,
      alternateVersionIds);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Asset &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.parentId == this.parentId &&
          other.type == this.type &&
          other.mimeType == this.mimeType &&
          other.name == this.name &&
          other.storagePath == this.storagePath &&
          other.sizeBytes == this.sizeBytes &&
          other.mappedStringFolderId == this.mappedStringFolderId &&
          other.description == this.description &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.sortOrder == this.sortOrder &&
          other.titleStringId == this.titleStringId &&
          other.collectionType == this.collectionType &&
          other.searchKeywords == this.searchKeywords &&
          other.relatedAssetIds == this.relatedAssetIds &&
          other.alternateVersionIds == this.alternateVersionIds);
}

class AssetsCompanion extends UpdateCompanion<Asset> {
  final Value<int> id;
  final Value<int> tenantId;
  final Value<int?> parentId;
  final Value<String> type;
  final Value<String?> mimeType;
  final Value<String> name;
  final Value<String?> storagePath;
  final Value<int?> sizeBytes;
  final Value<int?> mappedStringFolderId;
  final Value<String?> description;
  final Value<int?> createdAt;
  final Value<int?> updatedAt;
  final Value<int?> sortOrder;
  final Value<int?> titleStringId;
  final Value<String?> collectionType;
  final Value<String?> searchKeywords;
  final Value<String?> relatedAssetIds;
  final Value<String?> alternateVersionIds;
  const AssetsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.type = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.name = const Value.absent(),
    this.storagePath = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.mappedStringFolderId = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.titleStringId = const Value.absent(),
    this.collectionType = const Value.absent(),
    this.searchKeywords = const Value.absent(),
    this.relatedAssetIds = const Value.absent(),
    this.alternateVersionIds = const Value.absent(),
  });
  AssetsCompanion.insert({
    this.id = const Value.absent(),
    required int tenantId,
    this.parentId = const Value.absent(),
    required String type,
    this.mimeType = const Value.absent(),
    required String name,
    this.storagePath = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.mappedStringFolderId = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.titleStringId = const Value.absent(),
    this.collectionType = const Value.absent(),
    this.searchKeywords = const Value.absent(),
    this.relatedAssetIds = const Value.absent(),
    this.alternateVersionIds = const Value.absent(),
  })  : tenantId = Value(tenantId),
        type = Value(type),
        name = Value(name);
  static Insertable<Asset> custom({
    Expression<int>? id,
    Expression<int>? tenantId,
    Expression<int>? parentId,
    Expression<String>? type,
    Expression<String>? mimeType,
    Expression<String>? name,
    Expression<String>? storagePath,
    Expression<int>? sizeBytes,
    Expression<int>? mappedStringFolderId,
    Expression<String>? description,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? sortOrder,
    Expression<int>? titleStringId,
    Expression<String>? collectionType,
    Expression<String>? searchKeywords,
    Expression<String>? relatedAssetIds,
    Expression<String>? alternateVersionIds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (parentId != null) 'parent_id': parentId,
      if (type != null) 'type': type,
      if (mimeType != null) 'mime_type': mimeType,
      if (name != null) 'name': name,
      if (storagePath != null) 'storage_path': storagePath,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (mappedStringFolderId != null)
        'mapped_string_folder_id': mappedStringFolderId,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (titleStringId != null) 'title_string_id': titleStringId,
      if (collectionType != null) 'collection_type': collectionType,
      if (searchKeywords != null) 'search_keywords': searchKeywords,
      if (relatedAssetIds != null) 'related_asset_ids': relatedAssetIds,
      if (alternateVersionIds != null)
        'alternate_version_ids': alternateVersionIds,
    });
  }

  AssetsCompanion copyWith(
      {Value<int>? id,
      Value<int>? tenantId,
      Value<int?>? parentId,
      Value<String>? type,
      Value<String?>? mimeType,
      Value<String>? name,
      Value<String?>? storagePath,
      Value<int?>? sizeBytes,
      Value<int?>? mappedStringFolderId,
      Value<String?>? description,
      Value<int?>? createdAt,
      Value<int?>? updatedAt,
      Value<int?>? sortOrder,
      Value<int?>? titleStringId,
      Value<String?>? collectionType,
      Value<String?>? searchKeywords,
      Value<String?>? relatedAssetIds,
      Value<String?>? alternateVersionIds}) {
    return AssetsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      parentId: parentId ?? this.parentId,
      type: type ?? this.type,
      mimeType: mimeType ?? this.mimeType,
      name: name ?? this.name,
      storagePath: storagePath ?? this.storagePath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mappedStringFolderId: mappedStringFolderId ?? this.mappedStringFolderId,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      titleStringId: titleStringId ?? this.titleStringId,
      collectionType: collectionType ?? this.collectionType,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      relatedAssetIds: relatedAssetIds ?? this.relatedAssetIds,
      alternateVersionIds: alternateVersionIds ?? this.alternateVersionIds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<int>(tenantId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<int>(parentId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (storagePath.present) {
      map['storage_path'] = Variable<String>(storagePath.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (mappedStringFolderId.present) {
      map['mapped_string_folder_id'] =
          Variable<int>(mappedStringFolderId.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (titleStringId.present) {
      map['title_string_id'] = Variable<int>(titleStringId.value);
    }
    if (collectionType.present) {
      map['collection_type'] = Variable<String>(collectionType.value);
    }
    if (searchKeywords.present) {
      map['search_keywords'] = Variable<String>(searchKeywords.value);
    }
    if (relatedAssetIds.present) {
      map['related_asset_ids'] = Variable<String>(relatedAssetIds.value);
    }
    if (alternateVersionIds.present) {
      map['alternate_version_ids'] =
          Variable<String>(alternateVersionIds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssetsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('parentId: $parentId, ')
          ..write('type: $type, ')
          ..write('mimeType: $mimeType, ')
          ..write('name: $name, ')
          ..write('storagePath: $storagePath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('mappedStringFolderId: $mappedStringFolderId, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('titleStringId: $titleStringId, ')
          ..write('collectionType: $collectionType, ')
          ..write('searchKeywords: $searchKeywords, ')
          ..write('relatedAssetIds: $relatedAssetIds, ')
          ..write('alternateVersionIds: $alternateVersionIds')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _targetTableMeta =
      const VerificationMeta('targetTable');
  @override
  late final GeneratedColumn<String> targetTable = GeneratedColumn<String>(
      'target_table', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationMeta =
      const VerificationMeta('operation');
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
      'operation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, targetTable, operation, payloadJson, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(Insertable<SyncQueueData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('target_table')) {
      context.handle(
          _targetTableMeta,
          targetTable.isAcceptableOrUnknown(
              data['target_table']!, _targetTableMeta));
    } else if (isInserting) {
      context.missing(_targetTableMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(_operationMeta,
          operation.isAcceptableOrUnknown(data['operation']!, _operationMeta));
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      targetTable: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target_table'])!,
      operation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueData extends DataClass implements Insertable<SyncQueueData> {
  final int id;
  final String targetTable;
  final String operation;
  final String payloadJson;
  final DateTime createdAt;
  const SyncQueueData(
      {required this.id,
      required this.targetTable,
      required this.operation,
      required this.payloadJson,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['target_table'] = Variable<String>(targetTable);
    map['operation'] = Variable<String>(operation);
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      id: Value(id),
      targetTable: Value(targetTable),
      operation: Value(operation),
      payloadJson: Value(payloadJson),
      createdAt: Value(createdAt),
    );
  }

  factory SyncQueueData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueData(
      id: serializer.fromJson<int>(json['id']),
      targetTable: serializer.fromJson<String>(json['targetTable']),
      operation: serializer.fromJson<String>(json['operation']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'targetTable': serializer.toJson<String>(targetTable),
      'operation': serializer.toJson<String>(operation),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SyncQueueData copyWith(
          {int? id,
          String? targetTable,
          String? operation,
          String? payloadJson,
          DateTime? createdAt}) =>
      SyncQueueData(
        id: id ?? this.id,
        targetTable: targetTable ?? this.targetTable,
        operation: operation ?? this.operation,
        payloadJson: payloadJson ?? this.payloadJson,
        createdAt: createdAt ?? this.createdAt,
      );
  SyncQueueData copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueData(
      id: data.id.present ? data.id.value : this.id,
      targetTable:
          data.targetTable.present ? data.targetTable.value : this.targetTable,
      operation: data.operation.present ? data.operation.value : this.operation,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueData(')
          ..write('id: $id, ')
          ..write('targetTable: $targetTable, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, targetTable, operation, payloadJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueData &&
          other.id == this.id &&
          other.targetTable == this.targetTable &&
          other.operation == this.operation &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueData> {
  final Value<int> id;
  final Value<String> targetTable;
  final Value<String> operation;
  final Value<String> payloadJson;
  final Value<DateTime> createdAt;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.targetTable = const Value.absent(),
    this.operation = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required String targetTable,
    required String operation,
    required String payloadJson,
    this.createdAt = const Value.absent(),
  })  : targetTable = Value(targetTable),
        operation = Value(operation),
        payloadJson = Value(payloadJson);
  static Insertable<SyncQueueData> custom({
    Expression<int>? id,
    Expression<String>? targetTable,
    Expression<String>? operation,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (targetTable != null) 'target_table': targetTable,
      if (operation != null) 'operation': operation,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SyncQueueCompanion copyWith(
      {Value<int>? id,
      Value<String>? targetTable,
      Value<String>? operation,
      Value<String>? payloadJson,
      Value<DateTime>? createdAt}) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      targetTable: targetTable ?? this.targetTable,
      operation: operation ?? this.operation,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (targetTable.present) {
      map['target_table'] = Variable<String>(targetTable.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('targetTable: $targetTable, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $UserPreferencesTable extends UserPreferences
    with TableInfo<$UserPreferencesTable, UserPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _tenantIdMeta =
      const VerificationMeta('tenantId');
  @override
  late final GeneratedColumn<int> tenantId = GeneratedColumn<int>(
      'tenant_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _preferenceKeyMeta =
      const VerificationMeta('preferenceKey');
  @override
  late final GeneratedColumn<String> preferenceKey = GeneratedColumn<String>(
      'preference_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _preferenceValueMeta =
      const VerificationMeta('preferenceValue');
  @override
  late final GeneratedColumn<String> preferenceValue = GeneratedColumn<String>(
      'preference_value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, tenantId, preferenceKey, preferenceValue];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_preferences';
  @override
  VerificationContext validateIntegrity(Insertable<UserPreference> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tenant_id')) {
      context.handle(_tenantIdMeta,
          tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta));
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('preference_key')) {
      context.handle(
          _preferenceKeyMeta,
          preferenceKey.isAcceptableOrUnknown(
              data['preference_key']!, _preferenceKeyMeta));
    } else if (isInserting) {
      context.missing(_preferenceKeyMeta);
    }
    if (data.containsKey('preference_value')) {
      context.handle(
          _preferenceValueMeta,
          preferenceValue.isAcceptableOrUnknown(
              data['preference_value']!, _preferenceValueMeta));
    } else if (isInserting) {
      context.missing(_preferenceValueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {tenantId, preferenceKey},
      ];
  @override
  UserPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserPreference(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      tenantId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tenant_id'])!,
      preferenceKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}preference_key'])!,
      preferenceValue: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}preference_value'])!,
    );
  }

  @override
  $UserPreferencesTable createAlias(String alias) {
    return $UserPreferencesTable(attachedDatabase, alias);
  }
}

class UserPreference extends DataClass implements Insertable<UserPreference> {
  final int id;
  final int tenantId;
  final String preferenceKey;
  final String preferenceValue;
  const UserPreference(
      {required this.id,
      required this.tenantId,
      required this.preferenceKey,
      required this.preferenceValue});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tenant_id'] = Variable<int>(tenantId);
    map['preference_key'] = Variable<String>(preferenceKey);
    map['preference_value'] = Variable<String>(preferenceValue);
    return map;
  }

  UserPreferencesCompanion toCompanion(bool nullToAbsent) {
    return UserPreferencesCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      preferenceKey: Value(preferenceKey),
      preferenceValue: Value(preferenceValue),
    );
  }

  factory UserPreference.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserPreference(
      id: serializer.fromJson<int>(json['id']),
      tenantId: serializer.fromJson<int>(json['tenantId']),
      preferenceKey: serializer.fromJson<String>(json['preferenceKey']),
      preferenceValue: serializer.fromJson<String>(json['preferenceValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tenantId': serializer.toJson<int>(tenantId),
      'preferenceKey': serializer.toJson<String>(preferenceKey),
      'preferenceValue': serializer.toJson<String>(preferenceValue),
    };
  }

  UserPreference copyWith(
          {int? id,
          int? tenantId,
          String? preferenceKey,
          String? preferenceValue}) =>
      UserPreference(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        preferenceKey: preferenceKey ?? this.preferenceKey,
        preferenceValue: preferenceValue ?? this.preferenceValue,
      );
  UserPreference copyWithCompanion(UserPreferencesCompanion data) {
    return UserPreference(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      preferenceKey: data.preferenceKey.present
          ? data.preferenceKey.value
          : this.preferenceKey,
      preferenceValue: data.preferenceValue.present
          ? data.preferenceValue.value
          : this.preferenceValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserPreference(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('preferenceKey: $preferenceKey, ')
          ..write('preferenceValue: $preferenceValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tenantId, preferenceKey, preferenceValue);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserPreference &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.preferenceKey == this.preferenceKey &&
          other.preferenceValue == this.preferenceValue);
}

class UserPreferencesCompanion extends UpdateCompanion<UserPreference> {
  final Value<int> id;
  final Value<int> tenantId;
  final Value<String> preferenceKey;
  final Value<String> preferenceValue;
  const UserPreferencesCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.preferenceKey = const Value.absent(),
    this.preferenceValue = const Value.absent(),
  });
  UserPreferencesCompanion.insert({
    this.id = const Value.absent(),
    required int tenantId,
    required String preferenceKey,
    required String preferenceValue,
  })  : tenantId = Value(tenantId),
        preferenceKey = Value(preferenceKey),
        preferenceValue = Value(preferenceValue);
  static Insertable<UserPreference> custom({
    Expression<int>? id,
    Expression<int>? tenantId,
    Expression<String>? preferenceKey,
    Expression<String>? preferenceValue,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (preferenceKey != null) 'preference_key': preferenceKey,
      if (preferenceValue != null) 'preference_value': preferenceValue,
    });
  }

  UserPreferencesCompanion copyWith(
      {Value<int>? id,
      Value<int>? tenantId,
      Value<String>? preferenceKey,
      Value<String>? preferenceValue}) {
    return UserPreferencesCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      preferenceKey: preferenceKey ?? this.preferenceKey,
      preferenceValue: preferenceValue ?? this.preferenceValue,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<int>(tenantId.value);
    }
    if (preferenceKey.present) {
      map['preference_key'] = Variable<String>(preferenceKey.value);
    }
    if (preferenceValue.present) {
      map['preference_value'] = Variable<String>(preferenceValue.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserPreferencesCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('preferenceKey: $preferenceKey, ')
          ..write('preferenceValue: $preferenceValue')
          ..write(')'))
        .toString();
  }
}

class $CheersTable extends Cheers with TableInfo<$CheersTable, Cheer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CheersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetIdMeta =
      const VerificationMeta('targetId');
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
      'target_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
      'amount', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, userId, targetId, amount, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cheers';
  @override
  VerificationContext validateIntegrity(Insertable<Cheer> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(_targetIdMeta,
          targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta));
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Cheer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Cheer(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      targetId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target_id'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $CheersTable createAlias(String alias) {
    return $CheersTable(attachedDatabase, alias);
  }
}

class Cheer extends DataClass implements Insertable<Cheer> {
  final String id;
  final String userId;
  final String targetId;
  final int amount;
  final DateTime createdAt;
  const Cheer(
      {required this.id,
      required this.userId,
      required this.targetId,
      required this.amount,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['target_id'] = Variable<String>(targetId);
    map['amount'] = Variable<int>(amount);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CheersCompanion toCompanion(bool nullToAbsent) {
    return CheersCompanion(
      id: Value(id),
      userId: Value(userId),
      targetId: Value(targetId),
      amount: Value(amount),
      createdAt: Value(createdAt),
    );
  }

  factory Cheer.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Cheer(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      targetId: serializer.fromJson<String>(json['targetId']),
      amount: serializer.fromJson<int>(json['amount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'targetId': serializer.toJson<String>(targetId),
      'amount': serializer.toJson<int>(amount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Cheer copyWith(
          {String? id,
          String? userId,
          String? targetId,
          int? amount,
          DateTime? createdAt}) =>
      Cheer(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        targetId: targetId ?? this.targetId,
        amount: amount ?? this.amount,
        createdAt: createdAt ?? this.createdAt,
      );
  Cheer copyWithCompanion(CheersCompanion data) {
    return Cheer(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      amount: data.amount.present ? data.amount.value : this.amount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Cheer(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('targetId: $targetId, ')
          ..write('amount: $amount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, targetId, amount, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cheer &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.targetId == this.targetId &&
          other.amount == this.amount &&
          other.createdAt == this.createdAt);
}

class CheersCompanion extends UpdateCompanion<Cheer> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> targetId;
  final Value<int> amount;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CheersCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.targetId = const Value.absent(),
    this.amount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CheersCompanion.insert({
    required String id,
    required String userId,
    required String targetId,
    required int amount,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        targetId = Value(targetId),
        amount = Value(amount);
  static Insertable<Cheer> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? targetId,
    Expression<int>? amount,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (targetId != null) 'target_id': targetId,
      if (amount != null) 'amount': amount,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CheersCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String>? targetId,
      Value<int>? amount,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return CheersCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      targetId: targetId ?? this.targetId,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
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
    return (StringBuffer('CheersCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('targetId: $targetId, ')
          ..write('amount: $amount, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AssetTagsTable assetTags = $AssetTagsTable(this);
  late final $AssetRelationsTable assetRelations = $AssetRelationsTable(this);
  late final $RecentPlaysTable recentPlays = $RecentPlaysTable(this);
  late final $PlaybackSessionTable playbackSession =
      $PlaybackSessionTable(this);
  late final $PlaybackQueueItemsTable playbackQueueItems =
      $PlaybackQueueItemsTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistItemsTable playlistItems = $PlaylistItemsTable(this);
  late final $RecentSearchesTable recentSearches = $RecentSearchesTable(this);
  late final $FavoritesCollectionsTable favoritesCollections =
      $FavoritesCollectionsTable(this);
  late final $FavoritesItemsTable favoritesItems = $FavoritesItemsTable(this);
  late final $AudioCacheTable audioCache = $AudioCacheTable(this);
  late final $StringsTable strings = $StringsTable(this);
  late final $LanguagesTable languages = $LanguagesTable(this);
  late final $TranslationsTable translations = $TranslationsTable(this);
  late final $AssetsTable assets = $AssetsTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $UserPreferencesTable userPreferences =
      $UserPreferencesTable(this);
  late final $CheersTable cheers = $CheersTable(this);
  late final AssetTagsDao assetTagsDao = AssetTagsDao(this as AppDatabase);
  late final AssetRelationsDao assetRelationsDao =
      AssetRelationsDao(this as AppDatabase);
  late final RecentPlaysDao recentPlaysDao =
      RecentPlaysDao(this as AppDatabase);
  late final PlaybackDao playbackDao = PlaybackDao(this as AppDatabase);
  late final PlaylistsDao playlistsDao = PlaylistsDao(this as AppDatabase);
  late final PlaylistItemsDao playlistItemsDao =
      PlaylistItemsDao(this as AppDatabase);
  late final RecentSearchesDao recentSearchesDao =
      RecentSearchesDao(this as AppDatabase);
  late final FavoritesDao favoritesDao = FavoritesDao(this as AppDatabase);
  late final AudioCacheDao audioCacheDao = AudioCacheDao(this as AppDatabase);
  late final I18nDao i18nDao = I18nDao(this as AppDatabase);
  late final AssetsDao assetsDao = AssetsDao(this as AppDatabase);
  late final SyncQueueDao syncQueueDao = SyncQueueDao(this as AppDatabase);
  late final UserPreferencesDao userPreferencesDao =
      UserPreferencesDao(this as AppDatabase);
  late final CheersDao cheersDao = CheersDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        assetTags,
        assetRelations,
        recentPlays,
        playbackSession,
        playbackQueueItems,
        playlists,
        playlistItems,
        recentSearches,
        favoritesCollections,
        favoritesItems,
        audioCache,
        strings,
        languages,
        translations,
        assets,
        syncQueue,
        userPreferences,
        cheers
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('playback_session',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('playback_queue_items', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$AssetTagsTableCreateCompanionBuilder = AssetTagsCompanion Function({
  required int assetId,
  required int stringId,
  Value<int?> createdAt,
  Value<int> rowid,
});
typedef $$AssetTagsTableUpdateCompanionBuilder = AssetTagsCompanion Function({
  Value<int> assetId,
  Value<int> stringId,
  Value<int?> createdAt,
  Value<int> rowid,
});

class $$AssetTagsTableFilterComposer
    extends Composer<_$AppDatabase, $AssetTagsTable> {
  $$AssetTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get assetId => $composableBuilder(
      column: $table.assetId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get stringId => $composableBuilder(
      column: $table.stringId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$AssetTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssetTagsTable> {
  $$AssetTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get assetId => $composableBuilder(
      column: $table.assetId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get stringId => $composableBuilder(
      column: $table.stringId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AssetTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssetTagsTable> {
  $$AssetTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<int> get stringId =>
      $composableBuilder(column: $table.stringId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AssetTagsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AssetTagsTable,
    AssetTag,
    $$AssetTagsTableFilterComposer,
    $$AssetTagsTableOrderingComposer,
    $$AssetTagsTableAnnotationComposer,
    $$AssetTagsTableCreateCompanionBuilder,
    $$AssetTagsTableUpdateCompanionBuilder,
    (AssetTag, BaseReferences<_$AppDatabase, $AssetTagsTable, AssetTag>),
    AssetTag,
    PrefetchHooks Function()> {
  $$AssetTagsTableTableManager(_$AppDatabase db, $AssetTagsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssetTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssetTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssetTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> assetId = const Value.absent(),
            Value<int> stringId = const Value.absent(),
            Value<int?> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AssetTagsCompanion(
            assetId: assetId,
            stringId: stringId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int assetId,
            required int stringId,
            Value<int?> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AssetTagsCompanion.insert(
            assetId: assetId,
            stringId: stringId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AssetTagsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AssetTagsTable,
    AssetTag,
    $$AssetTagsTableFilterComposer,
    $$AssetTagsTableOrderingComposer,
    $$AssetTagsTableAnnotationComposer,
    $$AssetTagsTableCreateCompanionBuilder,
    $$AssetTagsTableUpdateCompanionBuilder,
    (AssetTag, BaseReferences<_$AppDatabase, $AssetTagsTable, AssetTag>),
    AssetTag,
    PrefetchHooks Function()>;
typedef $$AssetRelationsTableCreateCompanionBuilder = AssetRelationsCompanion
    Function({
  required int primaryAssetId,
  required int relatedAssetId,
  required String relationType,
  Value<int?> createdAt,
  Value<int> rowid,
});
typedef $$AssetRelationsTableUpdateCompanionBuilder = AssetRelationsCompanion
    Function({
  Value<int> primaryAssetId,
  Value<int> relatedAssetId,
  Value<String> relationType,
  Value<int?> createdAt,
  Value<int> rowid,
});

class $$AssetRelationsTableFilterComposer
    extends Composer<_$AppDatabase, $AssetRelationsTable> {
  $$AssetRelationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get primaryAssetId => $composableBuilder(
      column: $table.primaryAssetId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get relatedAssetId => $composableBuilder(
      column: $table.relatedAssetId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get relationType => $composableBuilder(
      column: $table.relationType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$AssetRelationsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssetRelationsTable> {
  $$AssetRelationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get primaryAssetId => $composableBuilder(
      column: $table.primaryAssetId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get relatedAssetId => $composableBuilder(
      column: $table.relatedAssetId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get relationType => $composableBuilder(
      column: $table.relationType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AssetRelationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssetRelationsTable> {
  $$AssetRelationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get primaryAssetId => $composableBuilder(
      column: $table.primaryAssetId, builder: (column) => column);

  GeneratedColumn<int> get relatedAssetId => $composableBuilder(
      column: $table.relatedAssetId, builder: (column) => column);

  GeneratedColumn<String> get relationType => $composableBuilder(
      column: $table.relationType, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AssetRelationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AssetRelationsTable,
    AssetRelation,
    $$AssetRelationsTableFilterComposer,
    $$AssetRelationsTableOrderingComposer,
    $$AssetRelationsTableAnnotationComposer,
    $$AssetRelationsTableCreateCompanionBuilder,
    $$AssetRelationsTableUpdateCompanionBuilder,
    (
      AssetRelation,
      BaseReferences<_$AppDatabase, $AssetRelationsTable, AssetRelation>
    ),
    AssetRelation,
    PrefetchHooks Function()> {
  $$AssetRelationsTableTableManager(
      _$AppDatabase db, $AssetRelationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssetRelationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssetRelationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssetRelationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> primaryAssetId = const Value.absent(),
            Value<int> relatedAssetId = const Value.absent(),
            Value<String> relationType = const Value.absent(),
            Value<int?> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AssetRelationsCompanion(
            primaryAssetId: primaryAssetId,
            relatedAssetId: relatedAssetId,
            relationType: relationType,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int primaryAssetId,
            required int relatedAssetId,
            required String relationType,
            Value<int?> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AssetRelationsCompanion.insert(
            primaryAssetId: primaryAssetId,
            relatedAssetId: relatedAssetId,
            relationType: relationType,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AssetRelationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AssetRelationsTable,
    AssetRelation,
    $$AssetRelationsTableFilterComposer,
    $$AssetRelationsTableOrderingComposer,
    $$AssetRelationsTableAnnotationComposer,
    $$AssetRelationsTableCreateCompanionBuilder,
    $$AssetRelationsTableUpdateCompanionBuilder,
    (
      AssetRelation,
      BaseReferences<_$AppDatabase, $AssetRelationsTable, AssetRelation>
    ),
    AssetRelation,
    PrefetchHooks Function()>;
typedef $$RecentPlaysTableCreateCompanionBuilder = RecentPlaysCompanion
    Function({
  Value<int> id,
  required String itemId,
  required int playedAt,
  Value<String?> collectionId,
  Value<String?> collectionTitle,
  required String title,
  Value<String?> artist,
});
typedef $$RecentPlaysTableUpdateCompanionBuilder = RecentPlaysCompanion
    Function({
  Value<int> id,
  Value<String> itemId,
  Value<int> playedAt,
  Value<String?> collectionId,
  Value<String?> collectionTitle,
  Value<String> title,
  Value<String?> artist,
});

class $$RecentPlaysTableFilterComposer
    extends Composer<_$AppDatabase, $RecentPlaysTable> {
  $$RecentPlaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get playedAt => $composableBuilder(
      column: $table.playedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get collectionId => $composableBuilder(
      column: $table.collectionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get collectionTitle => $composableBuilder(
      column: $table.collectionTitle,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnFilters(column));
}

class $$RecentPlaysTableOrderingComposer
    extends Composer<_$AppDatabase, $RecentPlaysTable> {
  $$RecentPlaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get playedAt => $composableBuilder(
      column: $table.playedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get collectionId => $composableBuilder(
      column: $table.collectionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get collectionTitle => $composableBuilder(
      column: $table.collectionTitle,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnOrderings(column));
}

class $$RecentPlaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecentPlaysTable> {
  $$RecentPlaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);

  GeneratedColumn<String> get collectionId => $composableBuilder(
      column: $table.collectionId, builder: (column) => column);

  GeneratedColumn<String> get collectionTitle => $composableBuilder(
      column: $table.collectionTitle, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);
}

class $$RecentPlaysTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RecentPlaysTable,
    RecentPlay,
    $$RecentPlaysTableFilterComposer,
    $$RecentPlaysTableOrderingComposer,
    $$RecentPlaysTableAnnotationComposer,
    $$RecentPlaysTableCreateCompanionBuilder,
    $$RecentPlaysTableUpdateCompanionBuilder,
    (RecentPlay, BaseReferences<_$AppDatabase, $RecentPlaysTable, RecentPlay>),
    RecentPlay,
    PrefetchHooks Function()> {
  $$RecentPlaysTableTableManager(_$AppDatabase db, $RecentPlaysTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecentPlaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecentPlaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecentPlaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<int> playedAt = const Value.absent(),
            Value<String?> collectionId = const Value.absent(),
            Value<String?> collectionTitle = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> artist = const Value.absent(),
          }) =>
              RecentPlaysCompanion(
            id: id,
            itemId: itemId,
            playedAt: playedAt,
            collectionId: collectionId,
            collectionTitle: collectionTitle,
            title: title,
            artist: artist,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String itemId,
            required int playedAt,
            Value<String?> collectionId = const Value.absent(),
            Value<String?> collectionTitle = const Value.absent(),
            required String title,
            Value<String?> artist = const Value.absent(),
          }) =>
              RecentPlaysCompanion.insert(
            id: id,
            itemId: itemId,
            playedAt: playedAt,
            collectionId: collectionId,
            collectionTitle: collectionTitle,
            title: title,
            artist: artist,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RecentPlaysTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RecentPlaysTable,
    RecentPlay,
    $$RecentPlaysTableFilterComposer,
    $$RecentPlaysTableOrderingComposer,
    $$RecentPlaysTableAnnotationComposer,
    $$RecentPlaysTableCreateCompanionBuilder,
    $$RecentPlaysTableUpdateCompanionBuilder,
    (RecentPlay, BaseReferences<_$AppDatabase, $RecentPlaysTable, RecentPlay>),
    RecentPlay,
    PrefetchHooks Function()>;
typedef $$PlaybackSessionTableCreateCompanionBuilder = PlaybackSessionCompanion
    Function({
  Value<int> id,
  Value<int> currentIndex,
  Value<int> positionMs,
  Value<int> isShuffled,
  Value<int> repeatMode,
  required int updatedAt,
});
typedef $$PlaybackSessionTableUpdateCompanionBuilder = PlaybackSessionCompanion
    Function({
  Value<int> id,
  Value<int> currentIndex,
  Value<int> positionMs,
  Value<int> isShuffled,
  Value<int> repeatMode,
  Value<int> updatedAt,
});

final class $$PlaybackSessionTableReferences extends BaseReferences<
    _$AppDatabase, $PlaybackSessionTable, PlaybackSessionData> {
  $$PlaybackSessionTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaybackQueueItemsTable, List<PlaybackQueueItem>>
      _playbackQueueItemsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.playbackQueueItems,
              aliasName: $_aliasNameGenerator(
                  db.playbackSession.id, db.playbackQueueItems.sessionId));

  $$PlaybackQueueItemsTableProcessedTableManager get playbackQueueItemsRefs {
    final manager =
        $$PlaybackQueueItemsTableTableManager($_db, $_db.playbackQueueItems)
            .filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_playbackQueueItemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PlaybackSessionTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackSessionTable> {
  $$PlaybackSessionTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get currentIndex => $composableBuilder(
      column: $table.currentIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get positionMs => $composableBuilder(
      column: $table.positionMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get isShuffled => $composableBuilder(
      column: $table.isShuffled, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get repeatMode => $composableBuilder(
      column: $table.repeatMode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> playbackQueueItemsRefs(
      Expression<bool> Function($$PlaybackQueueItemsTableFilterComposer f) f) {
    final $$PlaybackQueueItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.playbackQueueItems,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaybackQueueItemsTableFilterComposer(
              $db: $db,
              $table: $db.playbackQueueItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PlaybackSessionTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackSessionTable> {
  $$PlaybackSessionTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get currentIndex => $composableBuilder(
      column: $table.currentIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get positionMs => $composableBuilder(
      column: $table.positionMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get isShuffled => $composableBuilder(
      column: $table.isShuffled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get repeatMode => $composableBuilder(
      column: $table.repeatMode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PlaybackSessionTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackSessionTable> {
  $$PlaybackSessionTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get currentIndex => $composableBuilder(
      column: $table.currentIndex, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
      column: $table.positionMs, builder: (column) => column);

  GeneratedColumn<int> get isShuffled => $composableBuilder(
      column: $table.isShuffled, builder: (column) => column);

  GeneratedColumn<int> get repeatMode => $composableBuilder(
      column: $table.repeatMode, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> playbackQueueItemsRefs<T extends Object>(
      Expression<T> Function($$PlaybackQueueItemsTableAnnotationComposer a) f) {
    final $$PlaybackQueueItemsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.playbackQueueItems,
            getReferencedColumn: (t) => t.sessionId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$PlaybackQueueItemsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.playbackQueueItems,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$PlaybackSessionTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlaybackSessionTable,
    PlaybackSessionData,
    $$PlaybackSessionTableFilterComposer,
    $$PlaybackSessionTableOrderingComposer,
    $$PlaybackSessionTableAnnotationComposer,
    $$PlaybackSessionTableCreateCompanionBuilder,
    $$PlaybackSessionTableUpdateCompanionBuilder,
    (PlaybackSessionData, $$PlaybackSessionTableReferences),
    PlaybackSessionData,
    PrefetchHooks Function({bool playbackQueueItemsRefs})> {
  $$PlaybackSessionTableTableManager(
      _$AppDatabase db, $PlaybackSessionTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackSessionTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackSessionTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackSessionTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> currentIndex = const Value.absent(),
            Value<int> positionMs = const Value.absent(),
            Value<int> isShuffled = const Value.absent(),
            Value<int> repeatMode = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
          }) =>
              PlaybackSessionCompanion(
            id: id,
            currentIndex: currentIndex,
            positionMs: positionMs,
            isShuffled: isShuffled,
            repeatMode: repeatMode,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> currentIndex = const Value.absent(),
            Value<int> positionMs = const Value.absent(),
            Value<int> isShuffled = const Value.absent(),
            Value<int> repeatMode = const Value.absent(),
            required int updatedAt,
          }) =>
              PlaybackSessionCompanion.insert(
            id: id,
            currentIndex: currentIndex,
            positionMs: positionMs,
            isShuffled: isShuffled,
            repeatMode: repeatMode,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PlaybackSessionTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({playbackQueueItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playbackQueueItemsRefs) db.playbackQueueItems
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playbackQueueItemsRefs)
                    await $_getPrefetchedData<PlaybackSessionData,
                            $PlaybackSessionTable, PlaybackQueueItem>(
                        currentTable: table,
                        referencedTable: $$PlaybackSessionTableReferences
                            ._playbackQueueItemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PlaybackSessionTableReferences(db, table, p0)
                                .playbackQueueItemsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$PlaybackSessionTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlaybackSessionTable,
    PlaybackSessionData,
    $$PlaybackSessionTableFilterComposer,
    $$PlaybackSessionTableOrderingComposer,
    $$PlaybackSessionTableAnnotationComposer,
    $$PlaybackSessionTableCreateCompanionBuilder,
    $$PlaybackSessionTableUpdateCompanionBuilder,
    (PlaybackSessionData, $$PlaybackSessionTableReferences),
    PlaybackSessionData,
    PrefetchHooks Function({bool playbackQueueItemsRefs})>;
typedef $$PlaybackQueueItemsTableCreateCompanionBuilder
    = PlaybackQueueItemsCompanion Function({
  required int sessionId,
  required int sortIndex,
  required String itemId,
  Value<String?> collectionId,
  Value<String?> title,
  Value<int> rowid,
});
typedef $$PlaybackQueueItemsTableUpdateCompanionBuilder
    = PlaybackQueueItemsCompanion Function({
  Value<int> sessionId,
  Value<int> sortIndex,
  Value<String> itemId,
  Value<String?> collectionId,
  Value<String?> title,
  Value<int> rowid,
});

final class $$PlaybackQueueItemsTableReferences extends BaseReferences<
    _$AppDatabase, $PlaybackQueueItemsTable, PlaybackQueueItem> {
  $$PlaybackQueueItemsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $PlaybackSessionTable _sessionIdTable(_$AppDatabase db) =>
      db.playbackSession.createAlias($_aliasNameGenerator(
          db.playbackQueueItems.sessionId, db.playbackSession.id));

  $$PlaybackSessionTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager =
        $$PlaybackSessionTableTableManager($_db, $_db.playbackSession)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PlaybackQueueItemsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackQueueItemsTable> {
  $$PlaybackQueueItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sortIndex => $composableBuilder(
      column: $table.sortIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get collectionId => $composableBuilder(
      column: $table.collectionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  $$PlaybackSessionTableFilterComposer get sessionId {
    final $$PlaybackSessionTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.playbackSession,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaybackSessionTableFilterComposer(
              $db: $db,
              $table: $db.playbackSession,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlaybackQueueItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackQueueItemsTable> {
  $$PlaybackQueueItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sortIndex => $composableBuilder(
      column: $table.sortIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get collectionId => $composableBuilder(
      column: $table.collectionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  $$PlaybackSessionTableOrderingComposer get sessionId {
    final $$PlaybackSessionTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.playbackSession,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaybackSessionTableOrderingComposer(
              $db: $db,
              $table: $db.playbackSession,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlaybackQueueItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackQueueItemsTable> {
  $$PlaybackQueueItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get collectionId => $composableBuilder(
      column: $table.collectionId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  $$PlaybackSessionTableAnnotationComposer get sessionId {
    final $$PlaybackSessionTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.playbackSession,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaybackSessionTableAnnotationComposer(
              $db: $db,
              $table: $db.playbackSession,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlaybackQueueItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlaybackQueueItemsTable,
    PlaybackQueueItem,
    $$PlaybackQueueItemsTableFilterComposer,
    $$PlaybackQueueItemsTableOrderingComposer,
    $$PlaybackQueueItemsTableAnnotationComposer,
    $$PlaybackQueueItemsTableCreateCompanionBuilder,
    $$PlaybackQueueItemsTableUpdateCompanionBuilder,
    (PlaybackQueueItem, $$PlaybackQueueItemsTableReferences),
    PlaybackQueueItem,
    PrefetchHooks Function({bool sessionId})> {
  $$PlaybackQueueItemsTableTableManager(
      _$AppDatabase db, $PlaybackQueueItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackQueueItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackQueueItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackQueueItemsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> sessionId = const Value.absent(),
            Value<int> sortIndex = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<String?> collectionId = const Value.absent(),
            Value<String?> title = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaybackQueueItemsCompanion(
            sessionId: sessionId,
            sortIndex: sortIndex,
            itemId: itemId,
            collectionId: collectionId,
            title: title,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int sessionId,
            required int sortIndex,
            required String itemId,
            Value<String?> collectionId = const Value.absent(),
            Value<String?> title = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaybackQueueItemsCompanion.insert(
            sessionId: sessionId,
            sortIndex: sortIndex,
            itemId: itemId,
            collectionId: collectionId,
            title: title,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PlaybackQueueItemsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable:
                        $$PlaybackQueueItemsTableReferences._sessionIdTable(db),
                    referencedColumn: $$PlaybackQueueItemsTableReferences
                        ._sessionIdTable(db)
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
        ));
}

typedef $$PlaybackQueueItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlaybackQueueItemsTable,
    PlaybackQueueItem,
    $$PlaybackQueueItemsTableFilterComposer,
    $$PlaybackQueueItemsTableOrderingComposer,
    $$PlaybackQueueItemsTableAnnotationComposer,
    $$PlaybackQueueItemsTableCreateCompanionBuilder,
    $$PlaybackQueueItemsTableUpdateCompanionBuilder,
    (PlaybackQueueItem, $$PlaybackQueueItemsTableReferences),
    PlaybackQueueItem,
    PrefetchHooks Function({bool sessionId})>;
typedef $$PlaylistsTableCreateCompanionBuilder = PlaylistsCompanion Function({
  required String id,
  required String name,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$PlaylistsTableUpdateCompanionBuilder = PlaylistsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlaylistsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlaylistsTable,
    Playlist,
    $$PlaylistsTableFilterComposer,
    $$PlaylistsTableOrderingComposer,
    $$PlaylistsTableAnnotationComposer,
    $$PlaylistsTableCreateCompanionBuilder,
    $$PlaylistsTableUpdateCompanionBuilder,
    (Playlist, BaseReferences<_$AppDatabase, $PlaylistsTable, Playlist>),
    Playlist,
    PrefetchHooks Function()> {
  $$PlaylistsTableTableManager(_$AppDatabase db, $PlaylistsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaylistsCompanion(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required int createdAt,
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaylistsCompanion.insert(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlaylistsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlaylistsTable,
    Playlist,
    $$PlaylistsTableFilterComposer,
    $$PlaylistsTableOrderingComposer,
    $$PlaylistsTableAnnotationComposer,
    $$PlaylistsTableCreateCompanionBuilder,
    $$PlaylistsTableUpdateCompanionBuilder,
    (Playlist, BaseReferences<_$AppDatabase, $PlaylistsTable, Playlist>),
    Playlist,
    PrefetchHooks Function()>;
typedef $$PlaylistItemsTableCreateCompanionBuilder = PlaylistItemsCompanion
    Function({
  required String playlistId,
  required int sortIndex,
  required String itemId,
  Value<String?> title,
  Value<String?> artist,
  Value<int> rowid,
});
typedef $$PlaylistItemsTableUpdateCompanionBuilder = PlaylistItemsCompanion
    Function({
  Value<String> playlistId,
  Value<int> sortIndex,
  Value<String> itemId,
  Value<String?> title,
  Value<String?> artist,
  Value<int> rowid,
});

class $$PlaylistItemsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistItemsTable> {
  $$PlaylistItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortIndex => $composableBuilder(
      column: $table.sortIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnFilters(column));
}

class $$PlaylistItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistItemsTable> {
  $$PlaylistItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortIndex => $composableBuilder(
      column: $table.sortIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnOrderings(column));
}

class $$PlaylistItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistItemsTable> {
  $$PlaylistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);
}

class $$PlaylistItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlaylistItemsTable,
    PlaylistItem,
    $$PlaylistItemsTableFilterComposer,
    $$PlaylistItemsTableOrderingComposer,
    $$PlaylistItemsTableAnnotationComposer,
    $$PlaylistItemsTableCreateCompanionBuilder,
    $$PlaylistItemsTableUpdateCompanionBuilder,
    (
      PlaylistItem,
      BaseReferences<_$AppDatabase, $PlaylistItemsTable, PlaylistItem>
    ),
    PlaylistItem,
    PrefetchHooks Function()> {
  $$PlaylistItemsTableTableManager(_$AppDatabase db, $PlaylistItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> playlistId = const Value.absent(),
            Value<int> sortIndex = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<String?> title = const Value.absent(),
            Value<String?> artist = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaylistItemsCompanion(
            playlistId: playlistId,
            sortIndex: sortIndex,
            itemId: itemId,
            title: title,
            artist: artist,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String playlistId,
            required int sortIndex,
            required String itemId,
            Value<String?> title = const Value.absent(),
            Value<String?> artist = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaylistItemsCompanion.insert(
            playlistId: playlistId,
            sortIndex: sortIndex,
            itemId: itemId,
            title: title,
            artist: artist,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlaylistItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlaylistItemsTable,
    PlaylistItem,
    $$PlaylistItemsTableFilterComposer,
    $$PlaylistItemsTableOrderingComposer,
    $$PlaylistItemsTableAnnotationComposer,
    $$PlaylistItemsTableCreateCompanionBuilder,
    $$PlaylistItemsTableUpdateCompanionBuilder,
    (
      PlaylistItem,
      BaseReferences<_$AppDatabase, $PlaylistItemsTable, PlaylistItem>
    ),
    PlaylistItem,
    PrefetchHooks Function()>;
typedef $$RecentSearchesTableCreateCompanionBuilder = RecentSearchesCompanion
    Function({
  Value<int> id,
  required String query,
  required DateTime searchedAt,
});
typedef $$RecentSearchesTableUpdateCompanionBuilder = RecentSearchesCompanion
    Function({
  Value<int> id,
  Value<String> query,
  Value<DateTime> searchedAt,
});

class $$RecentSearchesTableFilterComposer
    extends Composer<_$AppDatabase, $RecentSearchesTable> {
  $$RecentSearchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get query => $composableBuilder(
      column: $table.query, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get searchedAt => $composableBuilder(
      column: $table.searchedAt, builder: (column) => ColumnFilters(column));
}

class $$RecentSearchesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecentSearchesTable> {
  $$RecentSearchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get query => $composableBuilder(
      column: $table.query, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get searchedAt => $composableBuilder(
      column: $table.searchedAt, builder: (column) => ColumnOrderings(column));
}

class $$RecentSearchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecentSearchesTable> {
  $$RecentSearchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<DateTime> get searchedAt => $composableBuilder(
      column: $table.searchedAt, builder: (column) => column);
}

class $$RecentSearchesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RecentSearchesTable,
    RecentSearch,
    $$RecentSearchesTableFilterComposer,
    $$RecentSearchesTableOrderingComposer,
    $$RecentSearchesTableAnnotationComposer,
    $$RecentSearchesTableCreateCompanionBuilder,
    $$RecentSearchesTableUpdateCompanionBuilder,
    (
      RecentSearch,
      BaseReferences<_$AppDatabase, $RecentSearchesTable, RecentSearch>
    ),
    RecentSearch,
    PrefetchHooks Function()> {
  $$RecentSearchesTableTableManager(
      _$AppDatabase db, $RecentSearchesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecentSearchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecentSearchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecentSearchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> query = const Value.absent(),
            Value<DateTime> searchedAt = const Value.absent(),
          }) =>
              RecentSearchesCompanion(
            id: id,
            query: query,
            searchedAt: searchedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String query,
            required DateTime searchedAt,
          }) =>
              RecentSearchesCompanion.insert(
            id: id,
            query: query,
            searchedAt: searchedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RecentSearchesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RecentSearchesTable,
    RecentSearch,
    $$RecentSearchesTableFilterComposer,
    $$RecentSearchesTableOrderingComposer,
    $$RecentSearchesTableAnnotationComposer,
    $$RecentSearchesTableCreateCompanionBuilder,
    $$RecentSearchesTableUpdateCompanionBuilder,
    (
      RecentSearch,
      BaseReferences<_$AppDatabase, $RecentSearchesTable, RecentSearch>
    ),
    RecentSearch,
    PrefetchHooks Function()>;
typedef $$FavoritesCollectionsTableCreateCompanionBuilder
    = FavoritesCollectionsCompanion Function({
  required String collectionId,
  required DateTime favoritedAt,
  Value<int> rowid,
});
typedef $$FavoritesCollectionsTableUpdateCompanionBuilder
    = FavoritesCollectionsCompanion Function({
  Value<String> collectionId,
  Value<DateTime> favoritedAt,
  Value<int> rowid,
});

class $$FavoritesCollectionsTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesCollectionsTable> {
  $$FavoritesCollectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get collectionId => $composableBuilder(
      column: $table.collectionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get favoritedAt => $composableBuilder(
      column: $table.favoritedAt, builder: (column) => ColumnFilters(column));
}

class $$FavoritesCollectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesCollectionsTable> {
  $$FavoritesCollectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get collectionId => $composableBuilder(
      column: $table.collectionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get favoritedAt => $composableBuilder(
      column: $table.favoritedAt, builder: (column) => ColumnOrderings(column));
}

class $$FavoritesCollectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesCollectionsTable> {
  $$FavoritesCollectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get collectionId => $composableBuilder(
      column: $table.collectionId, builder: (column) => column);

  GeneratedColumn<DateTime> get favoritedAt => $composableBuilder(
      column: $table.favoritedAt, builder: (column) => column);
}

class $$FavoritesCollectionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FavoritesCollectionsTable,
    FavoriteCollection,
    $$FavoritesCollectionsTableFilterComposer,
    $$FavoritesCollectionsTableOrderingComposer,
    $$FavoritesCollectionsTableAnnotationComposer,
    $$FavoritesCollectionsTableCreateCompanionBuilder,
    $$FavoritesCollectionsTableUpdateCompanionBuilder,
    (
      FavoriteCollection,
      BaseReferences<_$AppDatabase, $FavoritesCollectionsTable,
          FavoriteCollection>
    ),
    FavoriteCollection,
    PrefetchHooks Function()> {
  $$FavoritesCollectionsTableTableManager(
      _$AppDatabase db, $FavoritesCollectionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesCollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesCollectionsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesCollectionsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> collectionId = const Value.absent(),
            Value<DateTime> favoritedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FavoritesCollectionsCompanion(
            collectionId: collectionId,
            favoritedAt: favoritedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String collectionId,
            required DateTime favoritedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              FavoritesCollectionsCompanion.insert(
            collectionId: collectionId,
            favoritedAt: favoritedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FavoritesCollectionsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $FavoritesCollectionsTable,
        FavoriteCollection,
        $$FavoritesCollectionsTableFilterComposer,
        $$FavoritesCollectionsTableOrderingComposer,
        $$FavoritesCollectionsTableAnnotationComposer,
        $$FavoritesCollectionsTableCreateCompanionBuilder,
        $$FavoritesCollectionsTableUpdateCompanionBuilder,
        (
          FavoriteCollection,
          BaseReferences<_$AppDatabase, $FavoritesCollectionsTable,
              FavoriteCollection>
        ),
        FavoriteCollection,
        PrefetchHooks Function()>;
typedef $$FavoritesItemsTableCreateCompanionBuilder = FavoritesItemsCompanion
    Function({
  required String itemId,
  required DateTime favoritedAt,
  Value<int> rowid,
});
typedef $$FavoritesItemsTableUpdateCompanionBuilder = FavoritesItemsCompanion
    Function({
  Value<String> itemId,
  Value<DateTime> favoritedAt,
  Value<int> rowid,
});

class $$FavoritesItemsTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesItemsTable> {
  $$FavoritesItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get favoritedAt => $composableBuilder(
      column: $table.favoritedAt, builder: (column) => ColumnFilters(column));
}

class $$FavoritesItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesItemsTable> {
  $$FavoritesItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get favoritedAt => $composableBuilder(
      column: $table.favoritedAt, builder: (column) => ColumnOrderings(column));
}

class $$FavoritesItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesItemsTable> {
  $$FavoritesItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<DateTime> get favoritedAt => $composableBuilder(
      column: $table.favoritedAt, builder: (column) => column);
}

class $$FavoritesItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FavoritesItemsTable,
    FavoriteItem,
    $$FavoritesItemsTableFilterComposer,
    $$FavoritesItemsTableOrderingComposer,
    $$FavoritesItemsTableAnnotationComposer,
    $$FavoritesItemsTableCreateCompanionBuilder,
    $$FavoritesItemsTableUpdateCompanionBuilder,
    (
      FavoriteItem,
      BaseReferences<_$AppDatabase, $FavoritesItemsTable, FavoriteItem>
    ),
    FavoriteItem,
    PrefetchHooks Function()> {
  $$FavoritesItemsTableTableManager(
      _$AppDatabase db, $FavoritesItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> itemId = const Value.absent(),
            Value<DateTime> favoritedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FavoritesItemsCompanion(
            itemId: itemId,
            favoritedAt: favoritedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String itemId,
            required DateTime favoritedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              FavoritesItemsCompanion.insert(
            itemId: itemId,
            favoritedAt: favoritedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FavoritesItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FavoritesItemsTable,
    FavoriteItem,
    $$FavoritesItemsTableFilterComposer,
    $$FavoritesItemsTableOrderingComposer,
    $$FavoritesItemsTableAnnotationComposer,
    $$FavoritesItemsTableCreateCompanionBuilder,
    $$FavoritesItemsTableUpdateCompanionBuilder,
    (
      FavoriteItem,
      BaseReferences<_$AppDatabase, $FavoritesItemsTable, FavoriteItem>
    ),
    FavoriteItem,
    PrefetchHooks Function()>;
typedef $$AudioCacheTableCreateCompanionBuilder = AudioCacheCompanion Function({
  required String itemId,
  required int status,
  Value<String?> localPath,
  Value<int?> fileBytes,
  Value<int> lastAccessedAt,
  Value<int> lastPlayedAt,
  Value<double> cacheScore,
  Value<String?> error,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$AudioCacheTableUpdateCompanionBuilder = AudioCacheCompanion Function({
  Value<String> itemId,
  Value<int> status,
  Value<String?> localPath,
  Value<int?> fileBytes,
  Value<int> lastAccessedAt,
  Value<int> lastPlayedAt,
  Value<double> cacheScore,
  Value<String?> error,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$AudioCacheTableFilterComposer
    extends Composer<_$AppDatabase, $AudioCacheTable> {
  $$AudioCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fileBytes => $composableBuilder(
      column: $table.fileBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastAccessedAt => $composableBuilder(
      column: $table.lastAccessedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastPlayedAt => $composableBuilder(
      column: $table.lastPlayedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get cacheScore => $composableBuilder(
      column: $table.cacheScore, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get error => $composableBuilder(
      column: $table.error, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$AudioCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $AudioCacheTable> {
  $$AudioCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fileBytes => $composableBuilder(
      column: $table.fileBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastAccessedAt => $composableBuilder(
      column: $table.lastAccessedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastPlayedAt => $composableBuilder(
      column: $table.lastPlayedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get cacheScore => $composableBuilder(
      column: $table.cacheScore, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get error => $composableBuilder(
      column: $table.error, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$AudioCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $AudioCacheTable> {
  $$AudioCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<int> get fileBytes =>
      $composableBuilder(column: $table.fileBytes, builder: (column) => column);

  GeneratedColumn<int> get lastAccessedAt => $composableBuilder(
      column: $table.lastAccessedAt, builder: (column) => column);

  GeneratedColumn<int> get lastPlayedAt => $composableBuilder(
      column: $table.lastPlayedAt, builder: (column) => column);

  GeneratedColumn<double> get cacheScore => $composableBuilder(
      column: $table.cacheScore, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AudioCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AudioCacheTable,
    AudioCacheEntry,
    $$AudioCacheTableFilterComposer,
    $$AudioCacheTableOrderingComposer,
    $$AudioCacheTableAnnotationComposer,
    $$AudioCacheTableCreateCompanionBuilder,
    $$AudioCacheTableUpdateCompanionBuilder,
    (
      AudioCacheEntry,
      BaseReferences<_$AppDatabase, $AudioCacheTable, AudioCacheEntry>
    ),
    AudioCacheEntry,
    PrefetchHooks Function()> {
  $$AudioCacheTableTableManager(_$AppDatabase db, $AudioCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudioCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudioCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AudioCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> itemId = const Value.absent(),
            Value<int> status = const Value.absent(),
            Value<String?> localPath = const Value.absent(),
            Value<int?> fileBytes = const Value.absent(),
            Value<int> lastAccessedAt = const Value.absent(),
            Value<int> lastPlayedAt = const Value.absent(),
            Value<double> cacheScore = const Value.absent(),
            Value<String?> error = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AudioCacheCompanion(
            itemId: itemId,
            status: status,
            localPath: localPath,
            fileBytes: fileBytes,
            lastAccessedAt: lastAccessedAt,
            lastPlayedAt: lastPlayedAt,
            cacheScore: cacheScore,
            error: error,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String itemId,
            required int status,
            Value<String?> localPath = const Value.absent(),
            Value<int?> fileBytes = const Value.absent(),
            Value<int> lastAccessedAt = const Value.absent(),
            Value<int> lastPlayedAt = const Value.absent(),
            Value<double> cacheScore = const Value.absent(),
            Value<String?> error = const Value.absent(),
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              AudioCacheCompanion.insert(
            itemId: itemId,
            status: status,
            localPath: localPath,
            fileBytes: fileBytes,
            lastAccessedAt: lastAccessedAt,
            lastPlayedAt: lastPlayedAt,
            cacheScore: cacheScore,
            error: error,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AudioCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AudioCacheTable,
    AudioCacheEntry,
    $$AudioCacheTableFilterComposer,
    $$AudioCacheTableOrderingComposer,
    $$AudioCacheTableAnnotationComposer,
    $$AudioCacheTableCreateCompanionBuilder,
    $$AudioCacheTableUpdateCompanionBuilder,
    (
      AudioCacheEntry,
      BaseReferences<_$AppDatabase, $AudioCacheTable, AudioCacheEntry>
    ),
    AudioCacheEntry,
    PrefetchHooks Function()>;
typedef $$StringsTableCreateCompanionBuilder = StringsCompanion Function({
  Value<int> id,
  required int tenantId,
  required String key,
  Value<String?> description,
  Value<int?> parentId,
  Value<String> type,
  Value<int> sortOrder,
  Value<String?> color,
  Value<String?> parameter,
  Value<int?> createdAt,
  Value<int?> updatedAt,
});
typedef $$StringsTableUpdateCompanionBuilder = StringsCompanion Function({
  Value<int> id,
  Value<int> tenantId,
  Value<String> key,
  Value<String?> description,
  Value<int?> parentId,
  Value<String> type,
  Value<int> sortOrder,
  Value<String?> color,
  Value<String?> parameter,
  Value<int?> createdAt,
  Value<int?> updatedAt,
});

final class $$StringsTableReferences
    extends BaseReferences<_$AppDatabase, $StringsTable, SystemString> {
  $$StringsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StringsTable _parentIdTable(_$AppDatabase db) => db.strings
      .createAlias($_aliasNameGenerator(db.strings.parentId, db.strings.id));

  $$StringsTableProcessedTableManager? get parentId {
    final $_column = $_itemColumn<int>('parent_id');
    if ($_column == null) return null;
    final manager = $$StringsTableTableManager($_db, $_db.strings)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$LanguagesTable, List<SystemLanguage>>
      _languagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.languages,
          aliasName:
              $_aliasNameGenerator(db.strings.id, db.languages.nameStringId));

  $$LanguagesTableProcessedTableManager get languagesRefs {
    final manager = $$LanguagesTableTableManager($_db, $_db.languages)
        .filter((f) => f.nameStringId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_languagesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$TranslationsTable, List<SystemTranslation>>
      _translationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.translations,
          aliasName:
              $_aliasNameGenerator(db.strings.id, db.translations.stringId));

  $$TranslationsTableProcessedTableManager get translationsRefs {
    final manager = $$TranslationsTableTableManager($_db, $_db.translations)
        .filter((f) => f.stringId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_translationsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$StringsTableFilterComposer
    extends Composer<_$AppDatabase, $StringsTable> {
  $$StringsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parameter => $composableBuilder(
      column: $table.parameter, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$StringsTableFilterComposer get parentId {
    final $$StringsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.strings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StringsTableFilterComposer(
              $db: $db,
              $table: $db.strings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> languagesRefs(
      Expression<bool> Function($$LanguagesTableFilterComposer f) f) {
    final $$LanguagesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.languages,
        getReferencedColumn: (t) => t.nameStringId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LanguagesTableFilterComposer(
              $db: $db,
              $table: $db.languages,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> translationsRefs(
      Expression<bool> Function($$TranslationsTableFilterComposer f) f) {
    final $$TranslationsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.translations,
        getReferencedColumn: (t) => t.stringId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TranslationsTableFilterComposer(
              $db: $db,
              $table: $db.translations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$StringsTableOrderingComposer
    extends Composer<_$AppDatabase, $StringsTable> {
  $$StringsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parameter => $composableBuilder(
      column: $table.parameter, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$StringsTableOrderingComposer get parentId {
    final $$StringsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.strings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StringsTableOrderingComposer(
              $db: $db,
              $table: $db.strings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$StringsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StringsTable> {
  $$StringsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get parameter =>
      $composableBuilder(column: $table.parameter, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$StringsTableAnnotationComposer get parentId {
    final $$StringsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.strings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StringsTableAnnotationComposer(
              $db: $db,
              $table: $db.strings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> languagesRefs<T extends Object>(
      Expression<T> Function($$LanguagesTableAnnotationComposer a) f) {
    final $$LanguagesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.languages,
        getReferencedColumn: (t) => t.nameStringId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LanguagesTableAnnotationComposer(
              $db: $db,
              $table: $db.languages,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> translationsRefs<T extends Object>(
      Expression<T> Function($$TranslationsTableAnnotationComposer a) f) {
    final $$TranslationsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.translations,
        getReferencedColumn: (t) => t.stringId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TranslationsTableAnnotationComposer(
              $db: $db,
              $table: $db.translations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$StringsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StringsTable,
    SystemString,
    $$StringsTableFilterComposer,
    $$StringsTableOrderingComposer,
    $$StringsTableAnnotationComposer,
    $$StringsTableCreateCompanionBuilder,
    $$StringsTableUpdateCompanionBuilder,
    (SystemString, $$StringsTableReferences),
    SystemString,
    PrefetchHooks Function(
        {bool parentId, bool languagesRefs, bool translationsRefs})> {
  $$StringsTableTableManager(_$AppDatabase db, $StringsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StringsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StringsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StringsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> tenantId = const Value.absent(),
            Value<String> key = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<int?> parentId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<String?> parameter = const Value.absent(),
            Value<int?> createdAt = const Value.absent(),
            Value<int?> updatedAt = const Value.absent(),
          }) =>
              StringsCompanion(
            id: id,
            tenantId: tenantId,
            key: key,
            description: description,
            parentId: parentId,
            type: type,
            sortOrder: sortOrder,
            color: color,
            parameter: parameter,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int tenantId,
            required String key,
            Value<String?> description = const Value.absent(),
            Value<int?> parentId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<String?> parameter = const Value.absent(),
            Value<int?> createdAt = const Value.absent(),
            Value<int?> updatedAt = const Value.absent(),
          }) =>
              StringsCompanion.insert(
            id: id,
            tenantId: tenantId,
            key: key,
            description: description,
            parentId: parentId,
            type: type,
            sortOrder: sortOrder,
            color: color,
            parameter: parameter,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$StringsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {parentId = false,
              languagesRefs = false,
              translationsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (languagesRefs) db.languages,
                if (translationsRefs) db.translations
              ],
              addJoins: <
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
                      dynamic>>(state) {
                if (parentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.parentId,
                    referencedTable:
                        $$StringsTableReferences._parentIdTable(db),
                    referencedColumn:
                        $$StringsTableReferences._parentIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (languagesRefs)
                    await $_getPrefetchedData<SystemString, $StringsTable,
                            SystemLanguage>(
                        currentTable: table,
                        referencedTable:
                            $$StringsTableReferences._languagesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$StringsTableReferences(db, table, p0)
                                .languagesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.nameStringId == item.id),
                        typedResults: items),
                  if (translationsRefs)
                    await $_getPrefetchedData<SystemString, $StringsTable,
                            SystemTranslation>(
                        currentTable: table,
                        referencedTable:
                            $$StringsTableReferences._translationsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$StringsTableReferences(db, table, p0)
                                .translationsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.stringId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$StringsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StringsTable,
    SystemString,
    $$StringsTableFilterComposer,
    $$StringsTableOrderingComposer,
    $$StringsTableAnnotationComposer,
    $$StringsTableCreateCompanionBuilder,
    $$StringsTableUpdateCompanionBuilder,
    (SystemString, $$StringsTableReferences),
    SystemString,
    PrefetchHooks Function(
        {bool parentId, bool languagesRefs, bool translationsRefs})>;
typedef $$LanguagesTableCreateCompanionBuilder = LanguagesCompanion Function({
  Value<int> id,
  required String code,
  Value<int?> nameStringId,
});
typedef $$LanguagesTableUpdateCompanionBuilder = LanguagesCompanion Function({
  Value<int> id,
  Value<String> code,
  Value<int?> nameStringId,
});

final class $$LanguagesTableReferences
    extends BaseReferences<_$AppDatabase, $LanguagesTable, SystemLanguage> {
  $$LanguagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StringsTable _nameStringIdTable(_$AppDatabase db) =>
      db.strings.createAlias(
          $_aliasNameGenerator(db.languages.nameStringId, db.strings.id));

  $$StringsTableProcessedTableManager? get nameStringId {
    final $_column = $_itemColumn<int>('name_string_id');
    if ($_column == null) return null;
    final manager = $$StringsTableTableManager($_db, $_db.strings)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_nameStringIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$TranslationsTable, List<SystemTranslation>>
      _translationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.translations,
          aliasName:
              $_aliasNameGenerator(db.languages.id, db.translations.langId));

  $$TranslationsTableProcessedTableManager get translationsRefs {
    final manager = $$TranslationsTableTableManager($_db, $_db.translations)
        .filter((f) => f.langId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_translationsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$LanguagesTableFilterComposer
    extends Composer<_$AppDatabase, $LanguagesTable> {
  $$LanguagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  $$StringsTableFilterComposer get nameStringId {
    final $$StringsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.nameStringId,
        referencedTable: $db.strings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StringsTableFilterComposer(
              $db: $db,
              $table: $db.strings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> translationsRefs(
      Expression<bool> Function($$TranslationsTableFilterComposer f) f) {
    final $$TranslationsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.translations,
        getReferencedColumn: (t) => t.langId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TranslationsTableFilterComposer(
              $db: $db,
              $table: $db.translations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$LanguagesTableOrderingComposer
    extends Composer<_$AppDatabase, $LanguagesTable> {
  $$LanguagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  $$StringsTableOrderingComposer get nameStringId {
    final $$StringsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.nameStringId,
        referencedTable: $db.strings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StringsTableOrderingComposer(
              $db: $db,
              $table: $db.strings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LanguagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LanguagesTable> {
  $$LanguagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  $$StringsTableAnnotationComposer get nameStringId {
    final $$StringsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.nameStringId,
        referencedTable: $db.strings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StringsTableAnnotationComposer(
              $db: $db,
              $table: $db.strings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> translationsRefs<T extends Object>(
      Expression<T> Function($$TranslationsTableAnnotationComposer a) f) {
    final $$TranslationsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.translations,
        getReferencedColumn: (t) => t.langId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TranslationsTableAnnotationComposer(
              $db: $db,
              $table: $db.translations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$LanguagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LanguagesTable,
    SystemLanguage,
    $$LanguagesTableFilterComposer,
    $$LanguagesTableOrderingComposer,
    $$LanguagesTableAnnotationComposer,
    $$LanguagesTableCreateCompanionBuilder,
    $$LanguagesTableUpdateCompanionBuilder,
    (SystemLanguage, $$LanguagesTableReferences),
    SystemLanguage,
    PrefetchHooks Function({bool nameStringId, bool translationsRefs})> {
  $$LanguagesTableTableManager(_$AppDatabase db, $LanguagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LanguagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LanguagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LanguagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> code = const Value.absent(),
            Value<int?> nameStringId = const Value.absent(),
          }) =>
              LanguagesCompanion(
            id: id,
            code: code,
            nameStringId: nameStringId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String code,
            Value<int?> nameStringId = const Value.absent(),
          }) =>
              LanguagesCompanion.insert(
            id: id,
            code: code,
            nameStringId: nameStringId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$LanguagesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {nameStringId = false, translationsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (translationsRefs) db.translations],
              addJoins: <
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
                      dynamic>>(state) {
                if (nameStringId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.nameStringId,
                    referencedTable:
                        $$LanguagesTableReferences._nameStringIdTable(db),
                    referencedColumn:
                        $$LanguagesTableReferences._nameStringIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (translationsRefs)
                    await $_getPrefetchedData<SystemLanguage, $LanguagesTable,
                            SystemTranslation>(
                        currentTable: table,
                        referencedTable: $$LanguagesTableReferences
                            ._translationsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$LanguagesTableReferences(db, table, p0)
                                .translationsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.langId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$LanguagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LanguagesTable,
    SystemLanguage,
    $$LanguagesTableFilterComposer,
    $$LanguagesTableOrderingComposer,
    $$LanguagesTableAnnotationComposer,
    $$LanguagesTableCreateCompanionBuilder,
    $$LanguagesTableUpdateCompanionBuilder,
    (SystemLanguage, $$LanguagesTableReferences),
    SystemLanguage,
    PrefetchHooks Function({bool nameStringId, bool translationsRefs})>;
typedef $$TranslationsTableCreateCompanionBuilder = TranslationsCompanion
    Function({
  Value<int> id,
  required int tenantId,
  required int stringId,
  required String value,
  required int langId,
  Value<int?> createdAt,
  Value<int?> updatedAt,
});
typedef $$TranslationsTableUpdateCompanionBuilder = TranslationsCompanion
    Function({
  Value<int> id,
  Value<int> tenantId,
  Value<int> stringId,
  Value<String> value,
  Value<int> langId,
  Value<int?> createdAt,
  Value<int?> updatedAt,
});

final class $$TranslationsTableReferences extends BaseReferences<_$AppDatabase,
    $TranslationsTable, SystemTranslation> {
  $$TranslationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StringsTable _stringIdTable(_$AppDatabase db) =>
      db.strings.createAlias(
          $_aliasNameGenerator(db.translations.stringId, db.strings.id));

  $$StringsTableProcessedTableManager get stringId {
    final $_column = $_itemColumn<int>('string_id')!;

    final manager = $$StringsTableTableManager($_db, $_db.strings)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_stringIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $LanguagesTable _langIdTable(_$AppDatabase db) =>
      db.languages.createAlias(
          $_aliasNameGenerator(db.translations.langId, db.languages.id));

  $$LanguagesTableProcessedTableManager get langId {
    final $_column = $_itemColumn<int>('lang_id')!;

    final manager = $$LanguagesTableTableManager($_db, $_db.languages)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_langIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$TranslationsTableFilterComposer
    extends Composer<_$AppDatabase, $TranslationsTable> {
  $$TranslationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$StringsTableFilterComposer get stringId {
    final $$StringsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.stringId,
        referencedTable: $db.strings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StringsTableFilterComposer(
              $db: $db,
              $table: $db.strings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$LanguagesTableFilterComposer get langId {
    final $$LanguagesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.langId,
        referencedTable: $db.languages,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LanguagesTableFilterComposer(
              $db: $db,
              $table: $db.languages,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TranslationsTableOrderingComposer
    extends Composer<_$AppDatabase, $TranslationsTable> {
  $$TranslationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$StringsTableOrderingComposer get stringId {
    final $$StringsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.stringId,
        referencedTable: $db.strings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StringsTableOrderingComposer(
              $db: $db,
              $table: $db.strings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$LanguagesTableOrderingComposer get langId {
    final $$LanguagesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.langId,
        referencedTable: $db.languages,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LanguagesTableOrderingComposer(
              $db: $db,
              $table: $db.languages,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TranslationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TranslationsTable> {
  $$TranslationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$StringsTableAnnotationComposer get stringId {
    final $$StringsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.stringId,
        referencedTable: $db.strings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StringsTableAnnotationComposer(
              $db: $db,
              $table: $db.strings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$LanguagesTableAnnotationComposer get langId {
    final $$LanguagesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.langId,
        referencedTable: $db.languages,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LanguagesTableAnnotationComposer(
              $db: $db,
              $table: $db.languages,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TranslationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TranslationsTable,
    SystemTranslation,
    $$TranslationsTableFilterComposer,
    $$TranslationsTableOrderingComposer,
    $$TranslationsTableAnnotationComposer,
    $$TranslationsTableCreateCompanionBuilder,
    $$TranslationsTableUpdateCompanionBuilder,
    (SystemTranslation, $$TranslationsTableReferences),
    SystemTranslation,
    PrefetchHooks Function({bool stringId, bool langId})> {
  $$TranslationsTableTableManager(_$AppDatabase db, $TranslationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranslationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranslationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranslationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> tenantId = const Value.absent(),
            Value<int> stringId = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> langId = const Value.absent(),
            Value<int?> createdAt = const Value.absent(),
            Value<int?> updatedAt = const Value.absent(),
          }) =>
              TranslationsCompanion(
            id: id,
            tenantId: tenantId,
            stringId: stringId,
            value: value,
            langId: langId,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int tenantId,
            required int stringId,
            required String value,
            required int langId,
            Value<int?> createdAt = const Value.absent(),
            Value<int?> updatedAt = const Value.absent(),
          }) =>
              TranslationsCompanion.insert(
            id: id,
            tenantId: tenantId,
            stringId: stringId,
            value: value,
            langId: langId,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$TranslationsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({stringId = false, langId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (stringId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.stringId,
                    referencedTable:
                        $$TranslationsTableReferences._stringIdTable(db),
                    referencedColumn:
                        $$TranslationsTableReferences._stringIdTable(db).id,
                  ) as T;
                }
                if (langId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.langId,
                    referencedTable:
                        $$TranslationsTableReferences._langIdTable(db),
                    referencedColumn:
                        $$TranslationsTableReferences._langIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$TranslationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TranslationsTable,
    SystemTranslation,
    $$TranslationsTableFilterComposer,
    $$TranslationsTableOrderingComposer,
    $$TranslationsTableAnnotationComposer,
    $$TranslationsTableCreateCompanionBuilder,
    $$TranslationsTableUpdateCompanionBuilder,
    (SystemTranslation, $$TranslationsTableReferences),
    SystemTranslation,
    PrefetchHooks Function({bool stringId, bool langId})>;
typedef $$AssetsTableCreateCompanionBuilder = AssetsCompanion Function({
  Value<int> id,
  required int tenantId,
  Value<int?> parentId,
  required String type,
  Value<String?> mimeType,
  required String name,
  Value<String?> storagePath,
  Value<int?> sizeBytes,
  Value<int?> mappedStringFolderId,
  Value<String?> description,
  Value<int?> createdAt,
  Value<int?> updatedAt,
  Value<int?> sortOrder,
  Value<int?> titleStringId,
  Value<String?> collectionType,
  Value<String?> searchKeywords,
  Value<String?> relatedAssetIds,
  Value<String?> alternateVersionIds,
});
typedef $$AssetsTableUpdateCompanionBuilder = AssetsCompanion Function({
  Value<int> id,
  Value<int> tenantId,
  Value<int?> parentId,
  Value<String> type,
  Value<String?> mimeType,
  Value<String> name,
  Value<String?> storagePath,
  Value<int?> sizeBytes,
  Value<int?> mappedStringFolderId,
  Value<String?> description,
  Value<int?> createdAt,
  Value<int?> updatedAt,
  Value<int?> sortOrder,
  Value<int?> titleStringId,
  Value<String?> collectionType,
  Value<String?> searchKeywords,
  Value<String?> relatedAssetIds,
  Value<String?> alternateVersionIds,
});

class $$AssetsTableFilterComposer
    extends Composer<_$AppDatabase, $AssetsTable> {
  $$AssetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mimeType => $composableBuilder(
      column: $table.mimeType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get storagePath => $composableBuilder(
      column: $table.storagePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get mappedStringFolderId => $composableBuilder(
      column: $table.mappedStringFolderId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get titleStringId => $composableBuilder(
      column: $table.titleStringId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get collectionType => $composableBuilder(
      column: $table.collectionType,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get searchKeywords => $composableBuilder(
      column: $table.searchKeywords,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get relatedAssetIds => $composableBuilder(
      column: $table.relatedAssetIds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get alternateVersionIds => $composableBuilder(
      column: $table.alternateVersionIds,
      builder: (column) => ColumnFilters(column));
}

class $$AssetsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssetsTable> {
  $$AssetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mimeType => $composableBuilder(
      column: $table.mimeType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get storagePath => $composableBuilder(
      column: $table.storagePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get mappedStringFolderId => $composableBuilder(
      column: $table.mappedStringFolderId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get titleStringId => $composableBuilder(
      column: $table.titleStringId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get collectionType => $composableBuilder(
      column: $table.collectionType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get searchKeywords => $composableBuilder(
      column: $table.searchKeywords,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get relatedAssetIds => $composableBuilder(
      column: $table.relatedAssetIds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get alternateVersionIds => $composableBuilder(
      column: $table.alternateVersionIds,
      builder: (column) => ColumnOrderings(column));
}

class $$AssetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssetsTable> {
  $$AssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<int> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get storagePath => $composableBuilder(
      column: $table.storagePath, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get mappedStringFolderId => $composableBuilder(
      column: $table.mappedStringFolderId, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get titleStringId => $composableBuilder(
      column: $table.titleStringId, builder: (column) => column);

  GeneratedColumn<String> get collectionType => $composableBuilder(
      column: $table.collectionType, builder: (column) => column);

  GeneratedColumn<String> get searchKeywords => $composableBuilder(
      column: $table.searchKeywords, builder: (column) => column);

  GeneratedColumn<String> get relatedAssetIds => $composableBuilder(
      column: $table.relatedAssetIds, builder: (column) => column);

  GeneratedColumn<String> get alternateVersionIds => $composableBuilder(
      column: $table.alternateVersionIds, builder: (column) => column);
}

class $$AssetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AssetsTable,
    Asset,
    $$AssetsTableFilterComposer,
    $$AssetsTableOrderingComposer,
    $$AssetsTableAnnotationComposer,
    $$AssetsTableCreateCompanionBuilder,
    $$AssetsTableUpdateCompanionBuilder,
    (Asset, BaseReferences<_$AppDatabase, $AssetsTable, Asset>),
    Asset,
    PrefetchHooks Function()> {
  $$AssetsTableTableManager(_$AppDatabase db, $AssetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> tenantId = const Value.absent(),
            Value<int?> parentId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String?> mimeType = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> storagePath = const Value.absent(),
            Value<int?> sizeBytes = const Value.absent(),
            Value<int?> mappedStringFolderId = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<int?> createdAt = const Value.absent(),
            Value<int?> updatedAt = const Value.absent(),
            Value<int?> sortOrder = const Value.absent(),
            Value<int?> titleStringId = const Value.absent(),
            Value<String?> collectionType = const Value.absent(),
            Value<String?> searchKeywords = const Value.absent(),
            Value<String?> relatedAssetIds = const Value.absent(),
            Value<String?> alternateVersionIds = const Value.absent(),
          }) =>
              AssetsCompanion(
            id: id,
            tenantId: tenantId,
            parentId: parentId,
            type: type,
            mimeType: mimeType,
            name: name,
            storagePath: storagePath,
            sizeBytes: sizeBytes,
            mappedStringFolderId: mappedStringFolderId,
            description: description,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sortOrder: sortOrder,
            titleStringId: titleStringId,
            collectionType: collectionType,
            searchKeywords: searchKeywords,
            relatedAssetIds: relatedAssetIds,
            alternateVersionIds: alternateVersionIds,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int tenantId,
            Value<int?> parentId = const Value.absent(),
            required String type,
            Value<String?> mimeType = const Value.absent(),
            required String name,
            Value<String?> storagePath = const Value.absent(),
            Value<int?> sizeBytes = const Value.absent(),
            Value<int?> mappedStringFolderId = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<int?> createdAt = const Value.absent(),
            Value<int?> updatedAt = const Value.absent(),
            Value<int?> sortOrder = const Value.absent(),
            Value<int?> titleStringId = const Value.absent(),
            Value<String?> collectionType = const Value.absent(),
            Value<String?> searchKeywords = const Value.absent(),
            Value<String?> relatedAssetIds = const Value.absent(),
            Value<String?> alternateVersionIds = const Value.absent(),
          }) =>
              AssetsCompanion.insert(
            id: id,
            tenantId: tenantId,
            parentId: parentId,
            type: type,
            mimeType: mimeType,
            name: name,
            storagePath: storagePath,
            sizeBytes: sizeBytes,
            mappedStringFolderId: mappedStringFolderId,
            description: description,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sortOrder: sortOrder,
            titleStringId: titleStringId,
            collectionType: collectionType,
            searchKeywords: searchKeywords,
            relatedAssetIds: relatedAssetIds,
            alternateVersionIds: alternateVersionIds,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AssetsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AssetsTable,
    Asset,
    $$AssetsTableFilterComposer,
    $$AssetsTableOrderingComposer,
    $$AssetsTableAnnotationComposer,
    $$AssetsTableCreateCompanionBuilder,
    $$AssetsTableUpdateCompanionBuilder,
    (Asset, BaseReferences<_$AppDatabase, $AssetsTable, Asset>),
    Asset,
    PrefetchHooks Function()>;
typedef $$SyncQueueTableCreateCompanionBuilder = SyncQueueCompanion Function({
  Value<int> id,
  required String targetTable,
  required String operation,
  required String payloadJson,
  Value<DateTime> createdAt,
});
typedef $$SyncQueueTableUpdateCompanionBuilder = SyncQueueCompanion Function({
  Value<int> id,
  Value<String> targetTable,
  Value<String> operation,
  Value<String> payloadJson,
  Value<DateTime> createdAt,
});

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetTable => $composableBuilder(
      column: $table.targetTable, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetTable => $composableBuilder(
      column: $table.targetTable, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get targetTable => $composableBuilder(
      column: $table.targetTable, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SyncQueueTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncQueueTable,
    SyncQueueData,
    $$SyncQueueTableFilterComposer,
    $$SyncQueueTableOrderingComposer,
    $$SyncQueueTableAnnotationComposer,
    $$SyncQueueTableCreateCompanionBuilder,
    $$SyncQueueTableUpdateCompanionBuilder,
    (
      SyncQueueData,
      BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>
    ),
    SyncQueueData,
    PrefetchHooks Function()> {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> targetTable = const Value.absent(),
            Value<String> operation = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              SyncQueueCompanion(
            id: id,
            targetTable: targetTable,
            operation: operation,
            payloadJson: payloadJson,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String targetTable,
            required String operation,
            required String payloadJson,
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              SyncQueueCompanion.insert(
            id: id,
            targetTable: targetTable,
            operation: operation,
            payloadJson: payloadJson,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncQueueTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncQueueTable,
    SyncQueueData,
    $$SyncQueueTableFilterComposer,
    $$SyncQueueTableOrderingComposer,
    $$SyncQueueTableAnnotationComposer,
    $$SyncQueueTableCreateCompanionBuilder,
    $$SyncQueueTableUpdateCompanionBuilder,
    (
      SyncQueueData,
      BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>
    ),
    SyncQueueData,
    PrefetchHooks Function()>;
typedef $$UserPreferencesTableCreateCompanionBuilder = UserPreferencesCompanion
    Function({
  Value<int> id,
  required int tenantId,
  required String preferenceKey,
  required String preferenceValue,
});
typedef $$UserPreferencesTableUpdateCompanionBuilder = UserPreferencesCompanion
    Function({
  Value<int> id,
  Value<int> tenantId,
  Value<String> preferenceKey,
  Value<String> preferenceValue,
});

class $$UserPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get preferenceKey => $composableBuilder(
      column: $table.preferenceKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get preferenceValue => $composableBuilder(
      column: $table.preferenceValue,
      builder: (column) => ColumnFilters(column));
}

class $$UserPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get preferenceKey => $composableBuilder(
      column: $table.preferenceKey,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get preferenceValue => $composableBuilder(
      column: $table.preferenceValue,
      builder: (column) => ColumnOrderings(column));
}

class $$UserPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get preferenceKey => $composableBuilder(
      column: $table.preferenceKey, builder: (column) => column);

  GeneratedColumn<String> get preferenceValue => $composableBuilder(
      column: $table.preferenceValue, builder: (column) => column);
}

class $$UserPreferencesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UserPreferencesTable,
    UserPreference,
    $$UserPreferencesTableFilterComposer,
    $$UserPreferencesTableOrderingComposer,
    $$UserPreferencesTableAnnotationComposer,
    $$UserPreferencesTableCreateCompanionBuilder,
    $$UserPreferencesTableUpdateCompanionBuilder,
    (
      UserPreference,
      BaseReferences<_$AppDatabase, $UserPreferencesTable, UserPreference>
    ),
    UserPreference,
    PrefetchHooks Function()> {
  $$UserPreferencesTableTableManager(
      _$AppDatabase db, $UserPreferencesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserPreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> tenantId = const Value.absent(),
            Value<String> preferenceKey = const Value.absent(),
            Value<String> preferenceValue = const Value.absent(),
          }) =>
              UserPreferencesCompanion(
            id: id,
            tenantId: tenantId,
            preferenceKey: preferenceKey,
            preferenceValue: preferenceValue,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int tenantId,
            required String preferenceKey,
            required String preferenceValue,
          }) =>
              UserPreferencesCompanion.insert(
            id: id,
            tenantId: tenantId,
            preferenceKey: preferenceKey,
            preferenceValue: preferenceValue,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UserPreferencesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UserPreferencesTable,
    UserPreference,
    $$UserPreferencesTableFilterComposer,
    $$UserPreferencesTableOrderingComposer,
    $$UserPreferencesTableAnnotationComposer,
    $$UserPreferencesTableCreateCompanionBuilder,
    $$UserPreferencesTableUpdateCompanionBuilder,
    (
      UserPreference,
      BaseReferences<_$AppDatabase, $UserPreferencesTable, UserPreference>
    ),
    UserPreference,
    PrefetchHooks Function()>;
typedef $$CheersTableCreateCompanionBuilder = CheersCompanion Function({
  required String id,
  required String userId,
  required String targetId,
  required int amount,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$CheersTableUpdateCompanionBuilder = CheersCompanion Function({
  Value<String> id,
  Value<String> userId,
  Value<String> targetId,
  Value<int> amount,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$CheersTableFilterComposer
    extends Composer<_$AppDatabase, $CheersTable> {
  $$CheersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetId => $composableBuilder(
      column: $table.targetId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$CheersTableOrderingComposer
    extends Composer<_$AppDatabase, $CheersTable> {
  $$CheersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetId => $composableBuilder(
      column: $table.targetId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$CheersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CheersTable> {
  $$CheersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CheersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CheersTable,
    Cheer,
    $$CheersTableFilterComposer,
    $$CheersTableOrderingComposer,
    $$CheersTableAnnotationComposer,
    $$CheersTableCreateCompanionBuilder,
    $$CheersTableUpdateCompanionBuilder,
    (Cheer, BaseReferences<_$AppDatabase, $CheersTable, Cheer>),
    Cheer,
    PrefetchHooks Function()> {
  $$CheersTableTableManager(_$AppDatabase db, $CheersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CheersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CheersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CheersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> targetId = const Value.absent(),
            Value<int> amount = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CheersCompanion(
            id: id,
            userId: userId,
            targetId: targetId,
            amount: amount,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            required String targetId,
            required int amount,
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CheersCompanion.insert(
            id: id,
            userId: userId,
            targetId: targetId,
            amount: amount,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CheersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CheersTable,
    Cheer,
    $$CheersTableFilterComposer,
    $$CheersTableOrderingComposer,
    $$CheersTableAnnotationComposer,
    $$CheersTableCreateCompanionBuilder,
    $$CheersTableUpdateCompanionBuilder,
    (Cheer, BaseReferences<_$AppDatabase, $CheersTable, Cheer>),
    Cheer,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AssetTagsTableTableManager get assetTags =>
      $$AssetTagsTableTableManager(_db, _db.assetTags);
  $$AssetRelationsTableTableManager get assetRelations =>
      $$AssetRelationsTableTableManager(_db, _db.assetRelations);
  $$RecentPlaysTableTableManager get recentPlays =>
      $$RecentPlaysTableTableManager(_db, _db.recentPlays);
  $$PlaybackSessionTableTableManager get playbackSession =>
      $$PlaybackSessionTableTableManager(_db, _db.playbackSession);
  $$PlaybackQueueItemsTableTableManager get playbackQueueItems =>
      $$PlaybackQueueItemsTableTableManager(_db, _db.playbackQueueItems);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistItemsTableTableManager get playlistItems =>
      $$PlaylistItemsTableTableManager(_db, _db.playlistItems);
  $$RecentSearchesTableTableManager get recentSearches =>
      $$RecentSearchesTableTableManager(_db, _db.recentSearches);
  $$FavoritesCollectionsTableTableManager get favoritesCollections =>
      $$FavoritesCollectionsTableTableManager(_db, _db.favoritesCollections);
  $$FavoritesItemsTableTableManager get favoritesItems =>
      $$FavoritesItemsTableTableManager(_db, _db.favoritesItems);
  $$AudioCacheTableTableManager get audioCache =>
      $$AudioCacheTableTableManager(_db, _db.audioCache);
  $$StringsTableTableManager get strings =>
      $$StringsTableTableManager(_db, _db.strings);
  $$LanguagesTableTableManager get languages =>
      $$LanguagesTableTableManager(_db, _db.languages);
  $$TranslationsTableTableManager get translations =>
      $$TranslationsTableTableManager(_db, _db.translations);
  $$AssetsTableTableManager get assets =>
      $$AssetsTableTableManager(_db, _db.assets);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$UserPreferencesTableTableManager get userPreferences =>
      $$UserPreferencesTableTableManager(_db, _db.userPreferences);
  $$CheersTableTableManager get cheers =>
      $$CheersTableTableManager(_db, _db.cheers);
}
