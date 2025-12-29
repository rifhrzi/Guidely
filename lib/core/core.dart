/// Core module exports for NavMate.
///
/// This barrel file exports all core services and utilities
/// for convenient importing throughout the app.
library;

// App state and services
export 'app/app_scope.dart';
export 'app/app_state.dart';
export 'app/services.dart';

// Accessibility
export 'accessibility/accessibility.dart';

// Data
export 'data/landmarks.dart';

// Destination matching
export 'destination/landmark_matcher.dart';

// Haptics
export 'haptics/haptics_service.dart';

// Location
export 'location/location_service.dart';

// Logging
export 'logging/logger.dart';

// Map
export 'map/campus_geojson.dart';
export 'map/campus_map_view.dart';
export 'map/mbtiles_db.dart';
export 'map/mbtiles_tile_provider.dart';

// Network
export 'network/connectivity_service.dart';

// Obstacle
export 'obstacle/obstacle.dart';
export 'obstacle/obstacle_monitor.dart';
export 'obstacle/obstacle_store.dart';
export 'obstacle/obstacle_sync_service.dart';

// Permissions
export 'permissions/permissions.dart';

// Routing
export 'routing/announcement_scheduler.dart';
export 'routing/graph.dart';
export 'routing/navigation_engine.dart';
export 'routing/pathfinder.dart';
export 'routing/turn_detector.dart';

// Semantics
export 'semantics/announcer.dart';

// Speech
export 'speech/stt_service.dart';

// TTS
export 'tts/tts_service.dart';

// Types
export 'types/geo.dart';

// Crowd (optional - for crowd density features)
export 'crowd/beacon_scanner.dart';
export 'crowd/crowd_estimator.dart';
export 'crowd/crowd_service.dart';
export 'crowd/crowd_zone.dart';




