# NavMate

Clean Flutter app scaffold for NavMate.

## Scripts
- Run: `flutter run`
- Analyze: `flutter analyze`
- Test: `flutter test`

## Project Structure
- `lib/`: App code (entrypoint in `lib/main.dart`)
- `android/`, `ios/`, `windows/`: Platform projects
- `test/`: Widget and unit tests

## Notes
- Generated/IDE files are ignored via `.gitignore`.
- Lints: `analysis_options.yaml` uses `flutter_lints`.

## Campus Map Strategy (University Only)
- Custom graph: Build a walkable-path graph (nodes/edges) for campus with accessibility tags (stairs, ramps). Embed as an asset and route offline via A*.
- Offline basemap (optional): Use `MBTiles` raster tiles rendered from your campus data for `flutter_map`, or MapLibre with a custom style. Blind users rely on voice/haptics, so map is secondary.
- Landmarks: Define named waypoints (buildings, crossings) for clearer spoken instructions and geofenced safety callouts.
- Offline-first: No server required; all routing and announcements work without connectivity.

### How to Create MBTiles From Scratch (Quick Path)
- Author data: Use your university GIS or extract from OpenStreetMap (only campus area).
- Style in QGIS: Load buildings/paths; keep simple, high-contrast styling.
- Export MBTiles: QGIS → Raster → Generate XYZ Tiles → Format: MBTiles. Zooms: 14–19.
- Copy file: Save as `assets/tiles/campus.mbtiles` (see `assets/tiles/README.txt`).

Notes:
- MBTiles uses TMS (tile_row from bottom). The app converts XYZ→TMS automatically.
- For vector tiles later, consider Tippecanoe + MapLibre (phase 2).
