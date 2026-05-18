import 'package:drift/drift.dart';
import '../../models/app_album.dart';
import '../app_database.dart';
import '../tables/assets_table.dart';

part 'assets_dao.g.dart';

@DriftAccessor(tables: [Assets])
class AssetsDao extends DatabaseAccessor<AppDatabase> with _$AssetsDaoMixin {
  AssetsDao(super.db);

  Stream<List<Asset>> watchAllAssets() => select(assets).watch();

  Stream<List<Asset>> watchAssetsInFolder(int tenantId, int? parentId) {
    final q = select(assets);
    if (parentId == null) {
      q.where((t) => t.tenantId.equals(tenantId) & t.parentId.isNull());
    } else {
      q.where((t) => t.tenantId.equals(tenantId) & t.parentId.equals(parentId));
    }
    return (q..orderBy([
       (a) => OrderingTerm(expression: a.type.equals('FOLDER'), mode: OrderingMode.desc),
       (a) => OrderingTerm(expression: a.sortOrder),
       (a) => OrderingTerm(expression: a.name)
    ])).watch();
  }

  Future<Asset?> getAssetById(int id) {
    return (select(assets)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<Asset?> getAssetByStoragePath(String path) {
    return (select(assets)..where((t) => t.storagePath.equals(path))).getSingleOrNull();
  }

  Future<int> insertAsset(AssetsCompanion asset) => into(assets).insert(asset);
  
  Future<void> updateAsset(AssetsCompanion asset) => update(assets).replace(asset);
  
  Future<int> deleteAsset(int id) => (delete(assets)..where((t) => t.id.equals(id))).go();

  Future<void> replaceAllAssets(List<Asset> allAssets) async {
    await batch((batch) {
      batch.deleteAll(assets);
      batch.insertAll(assets, allAssets, mode: InsertMode.insertOrReplace);
    });
  }

  Stream<List<Asset>> watchFoldersByQuery(String query, {int limit = 10}) {
     return (select(assets)
        ..where((t) => t.type.equals('FOLDER') & (t.name.like('%$query%') | t.searchKeywords.like('%$query%')))
        ..orderBy([(a) => OrderingTerm(expression: a.name)])
        ..limit(limit)
     ).watch();
  }

  Stream<List<Asset>> watchFilesByQuery(String query, {int limit = 50}) {
     return (select(assets)
        ..where((t) => t.type.equals('FILE') & (t.name.like('%$query%') | t.searchKeywords.like('%$query%')))
        ..orderBy([(a) => OrderingTerm(expression: a.name)])
        ..limit(limit)
     ).watch();
  }


  Future<List<Asset>> getFoldersInFolder(int parentId) {
     return (select(assets)
        ..where((t) => t.type.equals('FOLDER') & t.parentId.equals(parentId))
        ..orderBy([
           (a) => OrderingTerm(expression: a.sortOrder),
           (a) => OrderingTerm(expression: a.name)
        ])
     ).get();
  }

  Future<List<Asset>> getAssetsInFolder(int parentId) {
     return (select(assets)
        ..where((t) => t.type.equals('FILE') & t.parentId.equals(parentId))
        ..orderBy([
           (a) => OrderingTerm(expression: a.sortOrder),
           (a) => OrderingTerm(expression: a.name)
        ])
     ).get();
  }

  Stream<List<AppAlbum>> watchConfiguredAlbums(List<int> rootDomainIds) {
    if (rootDomainIds.isEmpty) return Stream.value([]);
    
    // Config passes top level domain IDs (e.g. Collections -> Music). We need the Folders visually under them as actual Albums.
    final albumQuery = select(assets)..where((t) => t.parentId.isIn(rootDomainIds) & t.type.equals('FOLDER'));
    
    return albumQuery.watch().asyncMap((albumFolders) async {
       List<AppAlbum> results = [];
       for (var album in albumFolders) {
          // Track Folders
          final trackFolders = await getFoldersInFolder(album.id);
          
          List<AppTrack> tracks = [];
          for (var tf in trackFolders) {
             final files = await getAssetsInFolder(tf.id);
             tracks.add(AppTrack(trackFolder: tf, files: files));
          }
          
          final albumFiles = await getAssetsInFolder(album.id);
          
          results.add(AppAlbum(albumFolder: album, tracks: tracks, albumFiles: albumFiles));
       }
       return results;
    });
  }
}
