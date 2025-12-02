import 'dart:async';

import 'package:flutter/material.dart';

import '../logging/logger.dart';
import 'campus_geojson.dart';
import 'mbtiles_db.dart';

class CampusMapData {
  const CampusMapData({required this.db, required this.overlays});

  final MbTilesDb db;
  final CampusGeoJson overlays;
}

typedef CampusMapWidgetBuilder =
    Widget Function(BuildContext context, CampusMapData data);

typedef CampusMapErrorBuilder =
    Widget Function(BuildContext context, Object error);

class CampusMapView extends StatefulWidget {
  const CampusMapView({
    super.key,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final CampusMapWidgetBuilder builder;
  final WidgetBuilder? loadingBuilder;
  final CampusMapErrorBuilder? errorBuilder;

  @override
  State<CampusMapView> createState() => _CampusMapViewState();
}

class _CampusMapViewState extends State<CampusMapView> {
  MbTilesDb? _db;
  CampusGeoJson? _geoJson;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    MbTilesDb? db;
    try {
      logDebug('Opening MBTiles database and GeoJSON overlays');
      db = await MbTilesDb.openFromAsset('assets/tiles/campus.mbtiles');
      final overlays = await loadCampusGeoJson();
      if (!mounted) {
        db.close();
        return;
      }
      setState(() {
        _db = db;
        _geoJson = overlays;
        _error = null;
      });
      logInfo('Campus map ready with ${overlays.buildings.length} buildings');
    } catch (error, stackTrace) {
      db?.close();
      logError(
        'Unable to initialise campus map',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      final errorBuilder = widget.errorBuilder;
      if (errorBuilder != null) {
        return errorBuilder(context, _error!);
      }
      return _DefaultErrorView(error: _error!);
    }

    final db = _db;
    final overlays = _geoJson;
    if (db == null || overlays == null) {
      final loadingBuilder = widget.loadingBuilder;
      if (loadingBuilder != null) {
        return loadingBuilder(context);
      }
      return const Center(child: CircularProgressIndicator());
    }

    return widget.builder(context, CampusMapData(db: db, overlays: overlays));
  }
}

class _DefaultErrorView extends StatelessWidget {
  const _DefaultErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'Failed to load the offline map. Please reinstall the assets or contact support.\nError: $error',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
