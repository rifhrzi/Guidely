# NavMate — Project Brief

This document summarizes the current state, goals, architecture, and usage of the NavMate Flutter app, focused on blind-friendly navigation within a university campus.

**Goals**
- Voice-first, hands-free navigation designed for blind and low-vision users.
- Campus-only: offline-capable routing with an embedded campus map and landmarks.
- Clear, slow, and consistent spoken guidance with optional haptics.
- Privacy-first: minimal data collection and offline operation where possible.

**Core Features (MVP)**
- Speak Destination: voice input with immediate listening, spoken confirmation, and retry.
- Confirmation: "Did you say '…'?" dialog with Yes / Try again / No.
- Navigation: large arrow view with live distance updates and arrival announcement.
- Campus Map: offline raster tiles (MBTiles) via `flutter_map`.
- Favorites: campus landmarks list (library, class hall, prayer hall) loaded from assets.
- Settings: accessibility voice hints, clarity mode (slower TTS), TTS speed slider, haptics toggle.
- Help: basic usage tips and available commands.

**App Structure**
- Features (UI pages)
  - `lib/features/home/home_page.dart`: Entry hub; buttons for Speak Destination, Favorites, Help; actions for Map, Settings.
  - `lib/features/destination/voice_destination_page.dart`: Voice capture page (auto-listen, confirm dialog, retry).
  - `lib/features/destination/confirm_destination_page.dart`: Shows recognized text; matches a campus landmark; starts navigation.
  - `lib/features/navigation/navigation_page.dart`: Guidance view; live distance, Repeat/Pause/End.
  - `lib/features/map/campus_map_page.dart`: MBTiles-backed map display.
  - `lib/features/favorites/favorites_page.dart`: Lists landmarks from assets.
  - `lib/features/settings/settings_page.dart`: Voice hints, clarity mode, TTS speed, haptics, screen reader status.
  - `lib/features/help/help_page.dart`: Voice commands and tips.

- Core (logic/services)
  - Accessibility: `lib/core/accessibility/accessibility.dart` (A11y.announce chooses screen reader vs TTS fallback).
  - App State: `lib/core/app/app_state.dart` (voiceHints, clarityMode, ttsRate); `lib/core/app/services.dart` (tts, stt, location singletons).
  - Speech: `lib/core/speech/stt_service.dart` (speech_to_text streaming with permissive session restarts and partial results).
  - TTS: `lib/core/tts/tts_service.dart` (FlutterTts integration, clarity mode, chunked speaking and pauses).
  - Location: `lib/core/location/location_service.dart` (Geolocator stream with permission checks).
  - Permissions: `lib/core/permissions/permissions.dart` (mic/location request wrappers).
  - Map: `lib/core/map/mbtiles_db.dart` (SQLite MBTiles reader), `lib/core/map/mbtiles_tile_provider.dart` (TileProvider for `flutter_map`).
  - Data: `lib/core/data/landmarks.dart` (load landmarks from JSON assets).
  - Routing (stubs):
    - `lib/core/routing/graph.dart` (Campus graph model: nodes/edges).
    - `lib/core/routing/navigation_engine.dart` (RoutePlan stub; replace with A* over campus graph).
    - `lib/core/routing/announcement_scheduler.dart` (schedule guidance announcements; placeholder).
  - Types: `lib/core/types/geo.dart` (`LatLng`, Haversine distance).

**Data & Assets**
- Landmarks file: `assets/data/landmarks.json`
  - Example schema:
    ```json
    [
      { "id": "library", "name": "Main Library", "type": "library", "lat": -6.200000, "lng": 106.816666 },
      { "id": "lecture_hall", "name": "Central Lecture Hall", "type": "class", "lat": -6.200500, "lng": 106.817100 },
      { "id": "prayer", "name": "Campus Prayer Hall", "type": "prayer", "lat": -6.200900, "lng": 106.816300 }
    ]
    ```
- MBTiles placement: `assets/tiles/campus.mbtiles`
  - See `assets/tiles/README.txt` for instructions.
  - Recommended zoom levels: 14–19 for typical campuses.
  - App converts XYZ → TMS internally for MBTiles tile_row.

**Routing (Current vs Planned)**
- Current: Straight-line stub (no turn-by-turn) for development.
- Planned: Offline A* over a campus walking-path graph.
  - Graph sources: OSM extract or university GIS. Include accessibility tags (ramps, stairs, slope, surface).
  - Step generator: Use landmark names for human-friendly instructions (e.g., "Pass the Library entrance, 25 meters").
  - Re-route: Off-route detection and quick recalculation.

**Accessibility**
- Screen reader detection: `A11y.screenReaderOn` reflects TalkBack/VoiceOver status.
- Announcements: `A11y.announce()` uses SemanticsService when a screen reader is active; otherwise uses TTS fallback when "Voice hints" is on.
- Clarity: Slower default TTS rate (0.7) with "Clarity mode" capping speed for intelligibility. TTS splits long sentences and inserts short pauses.
- Semantics: Large button targets (min height 64dp) with explicit labels on critical actions.
- Confirmation: Spoken confirmation ("Did you say …?"), with Yes/Try again/No dialog.

**Voice Input (STT)**
- Engine: `speech_to_text` (auto-restart, no listenFor timeout).
- Tuning: Streaming single-utterance, automatic punctuation, speaker diarization (1-2 speakers), 16 kHz sample rate, Indonesian locale enforced, custom vocabulary seeded from landmarks.
- Flow: VoiceDestination auto-listens on page open, allows "Listen again", then shows a confirmation dialog.

**Text-To-Speech (TTS)**
- Engine: `flutter_tts`.
- Settings: `AppState.ttsRate` slider (0.4–1.2), Clarity mode to keep speed in the 0.4–0.8 band.
- Behavior: Await completion between small chunks; short 150ms pause for pacing.

**Location**
- Engine: `geolocator` with high accuracy and a 1m distance filter.
- Flow: Navigation subscribes to `Stream<LatLng>` and computes Haversine distance to destination; announces arrival within ~8 meters.

**Permissions**
- Android (`android/app/src/main/AndroidManifest.xml`):
  - `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `RECORD_AUDIO`.
- iOS (`ios/Runner/Info.plist`):
  - `NSLocationWhenInUseUsageDescription`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`.

**Dependencies**
- UI/Map: `flutter_map`, `latlong2`.
- Storage/SQL: `sqlite3`, `sqlite3_flutter_libs`, `path_provider`.
- Speech/Voice: `speech_to_text`, `flutter_tts`.
- Sensors/Perms: `geolocator`, `permission_handler`.
- Lints: `flutter_lints` (via `analysis_options.yaml`).

**Development**
- Commands
  - Run: `flutter run`
  - Analyze: `flutter analyze`
  - Test: `flutter test`
- Tests
  - `test/widget_test.dart`: smoke test ensures Home renders and primary CTA exists.
- Lints
  - Uses Flutter recommended lints; keep warnings low; avoid unnecessary complexity.

**How To Add Campus Tiles**
- Create MBTiles from QGIS or other tools (export XYZ tiles → MBTiles, zoom 14–19).
- Copy to `assets/tiles/campus.mbtiles`.
- Ensure `pubspec.yaml` includes:
  ```yaml
  flutter:
    assets:
      - assets/tiles/
      - assets/data/landmarks.json
  ```

**How To Add Landmarks**
- Edit `assets/data/landmarks.json` with your campus POIs.
- Use clear types and names (e.g., `library`, `class`, `prayer`).

**File Map (Key Files)**
- App entry: `lib/main.dart`
- Features: `lib/features/{home, destination, navigation, map, favorites, settings, help}/...`
- Core services: `lib/core/{speech, tts, location, permissions, accessibility, app}/...`
- Map backend: `lib/core/map/{mbtiles_db.dart, mbtiles_tile_provider.dart}`
- Data/Types: `lib/core/data/landmarks.dart`, `lib/core/types/geo.dart`
- Routing stubs: `lib/core/routing/{graph.dart, navigation_engine.dart, announcement_scheduler.dart}`
- Assets: `assets/data/landmarks.json`, `assets/tiles/campus.mbtiles`

**Platform Notes**
- Android app label: `android/app/src/main/AndroidManifest.xml` → `android:label="NavMate"`.
- iOS display name: `ios/Runner/Info.plist` → `CFBundleDisplayName = NavMate`.
- Windows product strings updated to "NavMate".

**Privacy & Security**
- Location/microphone used only for navigation; no analytics by default.
- Offline-first design; routing and tiles can be packaged to avoid network dependency.
- API keys (if added later) should be secured and not shipped in source.

**Known Limitations**
- Routing is a stub; no turn-by-turn pathfinding yet.
- No background navigation service; app must stay in foreground for continuous guidance.
- No haptic patterns wired yet (placeholder service exists).
- STT relies on on-device models; very noisy environments may reduce accuracy.

**Next Steps (Recommended)**
- Implement offline A* routing over campus graph; generate step-by-step guidance with landmark names.
- Add synonyms and fuzzy matching for landmark names; optionally a language selector.
- Wire haptic patterns for left/right/straight/arrived.
- Add landmark overlay to the map; tap-to-navigate from map.
- Optional: Background/foreground service on Android for persistent navigation.







