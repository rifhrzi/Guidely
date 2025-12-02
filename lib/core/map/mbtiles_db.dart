import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../logging/logger.dart';

class MbTilesException implements Exception {
  const MbTilesException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'MbTilesException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

class MbTilesDb {
  final sqlite.Database _db;
  MbTilesDb._(this._db);

  static Future<MbTilesDb> openFromAsset(
    String assetPath, {
    String? logicalName,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = logicalName ?? assetPath.split('/').last;
      final dest = File('${dir.path}/$fileName');

      if (!await dest.exists()) {
        logInfo('Copying MBTiles asset to ${dest.path}');
        final bytes = await rootBundle.load(assetPath);
        await dest.writeAsBytes(bytes.buffer.asUint8List());
      }

      final db = sqlite.sqlite3.open(dest.path, mode: sqlite.OpenMode.readOnly);
      logDebug('Opened MBTiles file at ${dest.path}');
      return MbTilesDb._(db);
    } on FlutterError catch (error, stackTrace) {
      logError(
        'MBTiles asset not found: $assetPath',
        error: error,
        stackTrace: stackTrace,
      );
      throw MbTilesException('MBTiles asset not found: $assetPath', error);
    } on IOException catch (error, stackTrace) {
      logError(
        'Failed to copy MBTiles asset: $assetPath',
        error: error,
        stackTrace: stackTrace,
      );
      throw MbTilesException('Failed to copy MBTiles asset: $assetPath', error);
    } on sqlite.SqliteException catch (error, stackTrace) {
      logError(
        'Failed to open MBTiles database',
        error: error,
        stackTrace: stackTrace,
      );
      throw MbTilesException('Failed to open MBTiles database', error);
    }
  }

  Uint8List? getTileBytes({
    required int z,
    required int x,
    required int yIsXyz,
  }) {
    final tmsY = _xyzToTmsY(z, yIsXyz);
    final stmt = _db.prepare(
      'SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ? LIMIT 1',
    );
    try {
      final result = stmt.select([z, x, tmsY]);
      if (result.isEmpty) {
        logDebug('Missing tile at z=$z x=$x y=$yIsXyz');
        return null;
      }
      final data = result.first['tile_data'];
      if (data is Uint8List) {
        return Uint8List.fromList(data);
      }
      if (data is List<int>) {
        return Uint8List.fromList(data);
      }
      logWarn(
        'Unexpected tile data type for z=$z x=$x y=$yIsXyz (${data.runtimeType})',
      );
      return null;
    } on sqlite.SqliteException catch (error, stackTrace) {
      logError(
        'Failed to read tile z=$z x=$x y=$yIsXyz',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      stmt.dispose();
    }
  }

  void close() => _db.dispose();

  int _xyzToTmsY(int z, int y) => (1 << z) - 1 - y;
}
