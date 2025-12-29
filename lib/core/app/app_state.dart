import 'package:flutter/widgets.dart';

import '../data/landmarks.dart';

/// Enumeration of app operation modes.
enum AppMode {
  /// Online mode - full features with real-time sync.
  online,

  /// Offline mode - basic navigation with cached data.
  offline,
}

/// Holds user-facing application preferences and exposes them as [ValueNotifier]s
/// so the UI can respond to changes without relying on globals.
class AppState {
  AppState({
    bool voiceHintsEnabled = true,
    double ttsRate = 0.7,
    bool clarityModeEnabled = true,
    Locale? locale,
    Iterable<RecentDestination> initialRecentDestinations = const [],
    bool simulationEnabled = false,
    double simulationSpeed = 1.4,
    bool useSimulationMode = true, // Default: use simulation (for testing)
    AppMode initialAppMode = AppMode.offline, // Default: offline for accessibility
    bool obstacleWarningsEnabled = true,
    bool crowdDetectionEnabled = true,
    bool autoSyncEnabled = true,
  }) : voiceHints = ValueNotifier<bool>(voiceHintsEnabled),
       ttsRate = ValueNotifier<double>(ttsRate.clamp(0.1, 1.0)),
       clarityMode = ValueNotifier<bool>(clarityModeEnabled),
       locale = ValueNotifier<Locale?>(locale),
       recentDestinations = ValueNotifier<List<RecentDestination>>(
         List<RecentDestination>.unmodifiable(
           initialRecentDestinations.take(10),
         ),
       ),
       simulationMode = ValueNotifier<bool>(simulationEnabled),
       simulationSpeed = ValueNotifier<double>(simulationSpeed.clamp(0.5, 5.0)),
       useSimulation = ValueNotifier<bool>(useSimulationMode),
       appMode = ValueNotifier<AppMode>(initialAppMode),
       obstacleWarnings = ValueNotifier<bool>(obstacleWarningsEnabled),
       crowdDetection = ValueNotifier<bool>(crowdDetectionEnabled),
       autoSync = ValueNotifier<bool>(autoSyncEnabled),
       lastSyncTime = ValueNotifier<DateTime?>(null),
       isSyncing = ValueNotifier<bool>(false);

  final ValueNotifier<bool> voiceHints;
  final ValueNotifier<double> ttsRate;
  final ValueNotifier<bool> clarityMode;
  final ValueNotifier<Locale?> locale;
  final ValueNotifier<List<RecentDestination>> recentDestinations;
  
  /// Whether location simulation is currently active (runtime state).
  final ValueNotifier<bool> simulationMode;
  
  /// Simulation walking speed in m/s (default 1.4 m/s = ~5 km/h).
  final ValueNotifier<double> simulationSpeed;
  
  /// Whether to use simulation mode when navigating (user preference).
  /// When true, navigation will simulate walking instead of using real GPS.
  final ValueNotifier<bool> useSimulation;

  // === Online/Offline Mode ===
  
  /// Current app operation mode (online/offline).
  final ValueNotifier<AppMode> appMode;
  
  /// Whether obstacle warnings are enabled during navigation.
  final ValueNotifier<bool> obstacleWarnings;
  
  /// Whether crowd detection is enabled (online mode only).
  final ValueNotifier<bool> crowdDetection;
  
  /// Whether automatic sync is enabled when online.
  final ValueNotifier<bool> autoSync;
  
  /// Last successful sync timestamp.
  final ValueNotifier<DateTime?> lastSyncTime;
  
  /// Whether sync is currently in progress.
  final ValueNotifier<bool> isSyncing;

  /// Whether the app is in online mode.
  bool get isOnlineMode => appMode.value == AppMode.online;
  
  /// Whether the app is in offline mode.
  bool get isOfflineMode => appMode.value == AppMode.offline;

  void setVoiceHints(bool value) => voiceHints.value = value;
  void setTtsRate(double value) => ttsRate.value = value.clamp(0.1, 1.0);
  void setClarityMode(bool value) => clarityMode.value = value;
  void setLocale(Locale? value) => locale.value = value;
  void setSimulationMode(bool value) => simulationMode.value = value;
  void setSimulationSpeed(double value) => simulationSpeed.value = value.clamp(0.5, 5.0);
  void setUseSimulation(bool value) => useSimulation.value = value;
  
  // === Online/Offline Mode Setters ===
  void setAppMode(AppMode value) => appMode.value = value;
  void setOnlineMode() => appMode.value = AppMode.online;
  void setOfflineMode() => appMode.value = AppMode.offline;
  void setObstacleWarnings(bool value) => obstacleWarnings.value = value;
  void setCrowdDetection(bool value) => crowdDetection.value = value;
  void setAutoSync(bool value) => autoSync.value = value;
  void setLastSyncTime(DateTime? value) => lastSyncTime.value = value;
  void setIsSyncing(bool value) => isSyncing.value = value;

  void addRecentDestination(Landmark landmark) {
    final current = recentDestinations.value;
    final now = DateTime.now();
    final updated = [
      RecentDestination(
        id: landmark.id,
        name: landmark.name,
        type: landmark.type,
        lat: landmark.lat,
        lng: landmark.lng,
        accessedAt: now,
      ),
      ...current.where((entry) => entry.id != landmark.id),
    ].take(6).toList(growable: false);
    recentDestinations.value = List<RecentDestination>.unmodifiable(updated);
  }

  void clearRecentDestinations() {
    if (recentDestinations.value.isEmpty) return;
    recentDestinations.value = const [];
  }

  void dispose() {
    voiceHints.dispose();
    ttsRate.dispose();
    clarityMode.dispose();
    locale.dispose();
    recentDestinations.dispose();
    simulationMode.dispose();
    simulationSpeed.dispose();
    useSimulation.dispose();
    appMode.dispose();
    obstacleWarnings.dispose();
    crowdDetection.dispose();
    autoSync.dispose();
    lastSyncTime.dispose();
    isSyncing.dispose();
  }
}

class RecentDestination {
  const RecentDestination({
    required this.id,
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
    required this.accessedAt,
  });

  final String id;
  final String name;
  final String type;
  final double lat;
  final double lng;
  final DateTime accessedAt;

  RecentDestination copyWith({
    String? id,
    String? name,
    String? type,
    double? lat,
    double? lng,
    DateTime? accessedAt,
  }) {
    return RecentDestination(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      accessedAt: accessedAt ?? this.accessedAt,
    );
  }
}
