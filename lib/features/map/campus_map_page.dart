import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/map/campus_map_view.dart';
import '../../core/map/mbtiles_tile_provider.dart';
import '../../l10n/app_localizations.dart';

class CampusMapPage extends StatelessWidget {
  const CampusMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.campusMap)),
      body: CampusMapView(
        loadingBuilder: (_) => const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not initialise the offline map.\n'
              'Make sure assets/tiles/campus.mbtiles exists (run tool/build_mbtiles.py).\n'
              'Error: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        builder: (context, data) => FlutterMap(
          options: MapOptions(
            initialCenter: data.overlays.center,
            initialZoom: 17,
            interactionOptions: const InteractionOptions(
              enableMultiFingerGestureRace: true,
            ),
          ),
          children: [
            TileLayer(
              tileProvider: MbTilesTileProvider(data.db),
              urlTemplate: 'mbtiles://{z}/{x}/{y}',
              tileDimension: 256,
              minZoom: 12,
              maxZoom: 20,
            ),
            PolygonLayer(polygons: data.overlays.buildings),
            PolylineLayer(polylines: data.overlays.walkways),
            MarkerLayer(markers: data.overlays.pointsOfInterest),
          ],
        ),
      ),
    );
  }
}
