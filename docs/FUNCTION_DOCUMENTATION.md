# Dokumentasi Fungsi NavMate (Guidely)

Dokumen ini berisi penjelasan lengkap mengenai fungsi-fungsi utama yang terdapat dalam aplikasi NavMate - aplikasi navigasi kampus untuk tunanetra.

---

## Daftar Isi

1. [Main Application](#1-main-application)
2. [Core Services](#2-core-services)
3. [Location Services](#3-location-services)
4. [Routing & Navigation](#4-routing--navigation)
5. [Speech Services (TTS & STT)](#5-speech-services-tts--stt)
6. [Obstacle Detection](#6-obstacle-detection)
7. [Crowd Monitoring](#7-crowd-monitoring)
8. [Map & GeoJSON](#8-map--geojson)
9. [Landmark Matching](#9-landmark-matching)
10. [Haptic Feedback](#10-haptic-feedback)
11. [Accessibility](#11-accessibility)
12. [Connectivity](#12-connectivity)
13. [Utility Functions](#13-utility-functions)

---

## 1. Main Application

### `main()` - Entry Point Aplikasi
**File:** `lib/main.dart`

```dart
void main() async
```

**Deskripsi:**
Fungsi utama yang menginisialisasi aplikasi NavMate.

**Proses:**
1. Menginisialisasi Flutter binding
2. Menginisialisasi Firebase (opsional, untuk fitur online)
3. Membuat instance `AppState` untuk state management
4. Membuat instance `AppServices` untuk dependency injection
5. Menginisialisasi async services (obstacle detection, dll)
6. Menjalankan aplikasi dengan `AppScope` wrapper

---

## 2. Core Services

### `AppServices` - Service Container
**File:** `lib/core/app/services.dart`

Container untuk semua runtime services yang dapat di-inject dan di-override untuk testing.

#### Constructor
```dart
AppServices({
  required AppState appState,
  TtsService? tts,
  SttService? stt,
  LocationStream? location,
  HapticsService? haptics,
  AccessibilityService? accessibility,
  ConnectivityService? connectivity,
})
```

**Services yang dikelola:**
- `tts` - Text-to-Speech service
- `stt` - Speech-to-Text service
- `location` - Location stream (GPS atau simulasi)
- `haptics` - Haptic feedback service
- `accessibility` - Accessibility announcements
- `connectivity` - Network connectivity monitoring
- `obstacleStore` - Local obstacle storage
- `obstacleSyncService` - Firebase sync untuk obstacles
- `obstacleMonitor` - Obstacle proximity monitoring

#### `initializeAsyncServices()`
```dart
Future<void> initializeAsyncServices()
```
Menginisialisasi services yang memerlukan async setup (obstacle detection, dll).

#### `startSimulation()`
```dart
Future<void> startSimulation({
  required double targetLat,
  required double targetLng,
  double? startLat,
  double? startLng,
})
```
Memulai simulasi lokasi untuk testing navigasi tanpa GPS.

**Parameter:**
- `targetLat`, `targetLng` - Koordinat tujuan
- `startLat`, `startLng` - Koordinat awal (opsional, default: gerbang FKIP)

#### `stopSimulation()`
```dart
void stopSimulation()
```
Menghentikan simulasi dan kembali ke GPS asli.

#### `syncObstacles()`
```dart
Future<void> syncObstacles()
```
Sinkronisasi data obstacle dari Firebase.

---

## 3. Location Services

### `LocationStream` - Abstraksi Location
**File:** `lib/core/location/location_service.dart`

#### Interface
```dart
abstract class LocationStream {
  Stream<LatLng> get positions;
  Future<LatLng?> getCurrentPosition();
}
```

### `GeolocatorLocationStream` - GPS Real
Implementasi untuk GPS device asli.

#### `positions`
```dart
Stream<LatLng> get positions
```
Stream lokasi GPS dengan akurasi tinggi, update setiap 5 meter pergerakan.

#### `getCurrentPosition()`
```dart
Future<LatLng?> getCurrentPosition()
```
Mengambil posisi GPS saat ini. Fallback ke last known position jika gagal.

### `SimulatedLocationStream` - Simulasi Lokasi
Untuk testing navigasi tanpa GPS.

#### `configure()`
```dart
void configure(SimulationConfig config)
```
Mengkonfigurasi simulasi dengan path dan kecepatan jalan.

#### `start()`, `stop()`, `pause()`, `resume()`, `reset()`
Kontrol lifecycle simulasi.

### `SwitchableLocationStream`
Wrapper yang dapat beralih antara GPS real dan simulasi.

#### `enableSimulation()`
```dart
void enableSimulation(SimulationConfig config)
```
Mengaktifkan mode simulasi.

#### `disableSimulation()`
```dart
void disableSimulation()
```
Kembali ke GPS asli.

---

## 4. Routing & Navigation

### Pathfinder - Pencarian Rute
**File:** `lib/core/routing/pathfinder.dart`

#### `computeWalkwayPath()`
```dart
PathResult? computeWalkwayPath(
  List<Polyline> walkways,
  LatLng start,
  LatLng end,
)
```
Menghitung rute optimal dari titik awal ke tujuan menggunakan algoritma Dijkstra.

**Proses:**
1. Membangun graph dari data walkway
2. Mencari node terdekat untuk start dan end
3. Menjalankan Dijkstra dengan early exit optimization
4. Mengembalikan path dan total jarak

**Return:**
- `PathResult` dengan `points` (list koordinat) dan `lengthMeters` (total jarak)
- `null` jika tidak ada rute

#### `clearPathfinderCache()`
```dart
void clearPathfinderCache()
```
Membersihkan cache graph (untuk testing atau saat data walkway berubah).

### TurnDetector - Deteksi Belokan
**File:** `lib/core/routing/turn_detector.dart`

#### `detectTurns()`
```dart
List<Turn> detectTurns(List<LatLng> path, {String? destinationName})
```
Menganalisis path dan mendeteksi semua belokan.

**Proses:**
1. Simplifikasi path dengan Douglas-Peucker algorithm
2. Deteksi belokan dengan look-ahead method
3. Klasifikasi tipe belokan (lurus, kiri, kanan, tajam, dll)
4. Merge belokan yang terlalu dekat
5. Generate instruksi navigasi dalam Bahasa Indonesia

**Tipe Belokan (`TurnType`):**
- `straight` - Lurus terus
- `slightLeft/slightRight` - Agak ke kiri/kanan
- `left/right` - Belok kiri/kanan
- `sharpLeft/sharpRight` - Belok tajam
- `uTurn` - Putar balik
- `arrived` - Sampai tujuan

#### `findNextTurn()`
```dart
Turn? findNextTurn(List<Turn> turns, LatLng currentPosition, double distanceTraveled)
```
Mencari belokan berikutnya berdasarkan posisi saat ini.

#### `isApproachingTurn()`
```dart
bool isApproachingTurn(Turn turn, double distanceTraveled, {double threshold = 25})
```
Mengecek apakah user mendekati belokan (dalam 25 meter).

#### `hasReachedTurn()`
```dart
bool hasReachedTurn(Turn turn, double distanceTraveled, {double threshold = 8})
```
Mengecek apakah user sudah sampai di titik belokan (dalam 8 meter).

### NavigationEngine - Engine Navigasi
**File:** `lib/core/routing/navigation_engine.dart`

#### `plan()`
```dart
RoutePlan plan(LatLng start, LatLng end)
```
Membuat rencana navigasi dari titik awal ke tujuan.

---

## 5. Speech Services (TTS & STT)

### TtsService - Text-to-Speech
**File:** `lib/core/tts/tts_service.dart`

#### `speak()`
```dart
Future<void> speak(String text)
```
Mengucapkan teks dengan TTS.

**Fitur:**
- Mendukung Bahasa Indonesia dan Inggris
- Kecepatan bicara dapat diatur
- Clarity mode untuk bicara lebih lambat
- Chunking otomatis per kalimat

#### `stop()`
```dart
Future<void> stop()
```
Menghentikan TTS yang sedang berbicara.

### SttService - Speech-to-Text
**File:** `lib/core/speech/stt_service.dart`

#### `listenOnce()`
```dart
Future<String?> listenOnce({Duration timeout = const Duration(seconds: 12)})
```
Mendengarkan input suara user selama timeout tertentu.

**Proses:**
1. Request permission microphone
2. Inisialisasi speech engine
3. Mendengarkan dengan auto-restart jika berhenti prematur
4. Return teks yang dikenali atau null jika gagal

**Fitur:**
- Auto-restart hingga 4x jika speech engine berhenti prematur
- Partial results untuk UX yang lebih responsif
- Locale matching (Indonesia/English)

---

## 6. Obstacle Detection

### Obstacle - Model Data
**File:** `lib/core/obstacle/obstacle.dart`

```dart
class Obstacle {
  final String id;
  final String name;
  final String description;
  final double lat, lng;
  final double radiusMeters;
  final ObstacleType type;
  final DateTime reportedAt;
  final DateTime? expiresAt;
  final bool isActive;
}
```

**Tipe Obstacle (`ObstacleType`):**
- `construction` - Konstruksi/perbaikan jalan
- `flooding` - Genangan air
- `event` - Acara kampus
- `closedPath` - Jalur ditutup
- `debris` - Rintangan/puing
- `temporary` - Hambatan sementara

### ObstacleStore - Penyimpanan Lokal
**File:** `lib/core/obstacle/obstacle_store.dart`

SQLite storage untuk menyimpan data obstacle secara offline.

#### `open()`
```dart
static Future<ObstacleStore> open()
```
Membuka atau membuat database obstacle.

#### `upsert()`
```dart
void upsert(Obstacle obstacle)
```
Insert atau update satu obstacle.

#### `upsertAll()`
```dart
void upsertAll(List<Obstacle> obstacles)
```
Batch insert/update obstacles (dengan transaction).

#### `getObstaclesNearby()`
```dart
List<Obstacle> getObstaclesNearby(double lat, double lng, double radiusMeters)
```
Mengambil obstacles dalam radius tertentu dari posisi.

**Optimasi:**
1. Filter dengan bounding box (cepat)
2. Filter dengan haversine distance (akurat)

#### `getActiveObstacles()`
```dart
List<Obstacle> getActiveObstacles()
```
Mengambil semua obstacles yang aktif dan belum expired.

### ObstacleMonitor - Pemantauan Proximity
**File:** `lib/core/obstacle/obstacle_monitor.dart`

#### `checkProximity()`
```dart
Future<List<Obstacle>> checkProximity(LatLng position)
```
Mengecek obstacle terdekat dan memberikan peringatan via TTS/haptic.

**Level Peringatan:**
- **Alert** (30m) - Informasi: obstacle terdeteksi di depan
- **Warning** (15m) - Peringatan: semakin dekat
- **Danger** (8m) - Perhatian: sangat dekat

**Fitur:**
- Tracking per-obstacle untuk menghindari pengulangan
- Cooldown 20 detik antar announcement
- Haptic feedback sesuai level bahaya

---

## 7. Crowd Monitoring

### CrowdService - Service Utama
**File:** `lib/core/crowd/crowd_service.dart`

#### `initialize()`
```dart
Future<void> initialize()
```
Menginisialisasi crowd service dan setup Firebase sync.

#### `startDetection()`
```dart
Future<void> startDetection()
```
Memulai deteksi kepadatan via Bluetooth scanning.

#### `stopDetection()`
```dart
Future<void> stopDetection()
```
Menghentikan deteksi kepadatan.

#### `getZoneAt()`
```dart
CrowdZone? getZoneAt(LatLng position)
```
Mendapatkan crowd zone di posisi tertentu.

#### `announceCrowdStatus()`
```dart
Future<void> announceCrowdStatus()
```
Mengumumkan status kepadatan via TTS.

### CrowdEstimator - Estimasi Kepadatan
**File:** `lib/core/crowd/crowd_estimator.dart`

#### `currentDensity`
```dart
int get currentDensity
```
Estimasi kepadatan saat ini (0-100%).

#### `currentLevel`
```dart
CrowdLevel get currentLevel
```
Level kepadatan:
- `empty` - < 20%
- `low` - 20-40%
- `moderate` - 40-60%
- `high` - 60-80%
- `veryHigh` - > 80%

#### `getSpokenDescription()`
```dart
String getSpokenDescription()
```
Deskripsi kepadatan untuk TTS.

---

## 8. Map & GeoJSON

### loadCampusGeoJson()
**File:** `lib/core/map/campus_geojson.dart`

```dart
Future<CampusGeoJson> loadCampusGeoJson()
```
Memuat data GeoJSON kampus dari assets.

**Data yang dimuat:**
- `buildings` - Polygon gedung
- `walkways` - Polyline jalur pejalan kaki
- `pointsOfInterest` - Marker POI
- `center` - Titik tengah kampus
- `bounds` - Batas area kampus

**Fitur:**
- Singleton cache untuk menghindari loading berulang
- Support MultiPolygon dan MultiLineString
- Automatic bounds calculation

### CampusBounds
```dart
class CampusBounds {
  bool contains(LatLng value);
  LatLng clamp(LatLng value);
}
```
Membatasi posisi dalam area kampus.

---

## 9. Landmark Matching

### LandmarkMatcher
**File:** `lib/core/destination/landmark_matcher.dart`

#### `bestMatch()`
```dart
Landmark? bestMatch({required String query, required LandmarkStore store})
```
Mencari landmark yang paling cocok dengan query suara user.

**Algoritma Scoring:**
1. **Exact match** (200 poin) - Nama persis sama
2. **Contains match** (90 poin) - Query terkandung dalam nama
3. **Token overlap** (50 poin) - Kata-kata yang sama
4. **Prefix match** (20 poin) - Awalan kata yang sama
5. **Similarity** (30 poin) - Kemiripan dengan Levenshtein distance

**Threshold:** Minimal 45 poin untuk dianggap cocok.

#### `_levenshtein()`
```dart
int _levenshtein(String a, String b)
```
Menghitung edit distance antara dua string (untuk fuzzy matching).

### LandmarkStore
**File:** `lib/core/data/landmarks.dart`

#### `loadFromAssets()`
```dart
static Future<LandmarkStore> loadFromAssets([String path])
```
Memuat data landmark dari JSON dan GeoJSON POI.

---

## 10. Haptic Feedback

### HapticsService
**File:** `lib/core/haptics/haptics_service.dart`

#### Navigation Haptics
- `tick()` - Vibrasi ringan (konfirmasi)
- `confirm()` - Light impact
- `arrived()` - Medium impact (sampai tujuan)
- `left()` - Light + selection (belok kiri)
- `right()` - Selection + light (belok kanan)
- `straight()` - Selection click (lurus)

#### Warning Haptics
- `warning()` - Double medium impact (peringatan)
- `danger()` - Triple heavy impact (bahaya/obstacle)

---

## 11. Accessibility

### AccessibilityService
**File:** `lib/core/accessibility/accessibility.dart`

#### `announce()`
```dart
Future<void> announce(String message, {TextDirection direction})
```
Mengumumkan pesan ke user.

**Prioritas:**
1. Screen reader (TalkBack/VoiceOver) jika aktif
2. TTS jika voice hints diaktifkan

---

## 12. Connectivity

### ConnectivityService
**File:** `lib/core/network/connectivity_service.dart`

#### `status`
```dart
ConnectivityStatus get status
```
Status konektivitas saat ini (online/offline/unknown).

#### `isOnline`
```dart
bool get isOnline
```
Apakah device sedang online.

#### `statusStream`
```dart
Stream<ConnectivityStatus> get statusStream
```
Stream perubahan konektivitas.

#### `refresh()`
```dart
Future<void> refresh()
```
Force refresh status konektivitas.

---

## 13. Utility Functions

### Geo Utilities
**File:** `lib/core/types/geo.dart`

#### `haversineMeters()`
```dart
double haversineMeters(LatLng a, LatLng b)
```
Menghitung jarak antara dua koordinat dalam meter menggunakan formula Haversine.

**Formula:**
```
d = 2 * R * arcsin(sqrt(sin²(Δlat/2) + cos(lat1) * cos(lat2) * sin²(Δlon/2)))
```

Di mana R = 6,371,000 meter (radius bumi).

### LatLng
```dart
class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);
}
```
Representasi koordinat geografis.

---

## Diagram Arsitektur

```
┌─────────────────────────────────────────────────────────────────┐
│                         NavMateApp                               │
├─────────────────────────────────────────────────────────────────┤
│                          AppScope                                │
│  ┌─────────────┐  ┌─────────────┐                               │
│  │  AppState   │  │ AppServices │                               │
│  └─────────────┘  └──────┬──────┘                               │
│                          │                                       │
├──────────────────────────┼──────────────────────────────────────┤
│                          ▼                                       │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    Core Services                             ││
│  ├──────────────┬──────────────┬──────────────┬────────────────┤│
│  │ LocationSvc  │   TtsSvc     │   SttSvc     │  HapticsSvc    ││
│  ├──────────────┼──────────────┼──────────────┼────────────────┤│
│  │ ObstacleSvc  │  CrowdSvc    │ Connectivity │ Accessibility  ││
│  └──────────────┴──────────────┴──────────────┴────────────────┘│
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    Routing Engine                            ││
│  ├──────────────┬──────────────┬──────────────────────────────┤│
│  │  Pathfinder  │ TurnDetector │ AnnouncementScheduler         ││
│  └──────────────┴──────────────┴──────────────────────────────┘│
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    Data Layer                                ││
│  ├──────────────┬──────────────┬──────────────────────────────┤│
│  │ LandmarkStore│ObstacleStore │ CampusGeoJson                 ││
│  └──────────────┴──────────────┴──────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

---

## Flow Navigasi

```
1. User mengucapkan tujuan
           │
           ▼
2. STT mengkonversi ke teks
           │
           ▼
3. LandmarkMatcher mencari landmark
           │
           ▼
4. Pathfinder menghitung rute optimal
           │
           ▼
5. TurnDetector menganalisis belokan
           │
           ▼
6. Navigation loop dimulai:
   ┌───────────────────────────────┐
   │ a. Location update diterima   │
   │ b. Cek proximity obstacle     │
   │ c. Update jarak ke belokan    │
   │ d. Announce instruksi via TTS │
   │ e. Haptic feedback            │
   └───────────────────────────────┘
           │
           ▼
7. User sampai di tujuan
```

---

## Catatan Teknis

### Threading & Async
- Semua operasi I/O menggunakan `async/await`
- Location stream menggunakan `Stream<LatLng>` untuk reactive updates
- TTS operations di-queue untuk menghindari overlap

### Offline Support
- Landmark data di-bundle dalam assets
- Obstacles disimpan di SQLite lokal
- Firebase sync dilakukan saat online

### Performance Optimizations
- Graph caching untuk pathfinding
- GeoJSON caching untuk map data
- Bounding box filtering sebelum distance calculation
- Early exit dalam Dijkstra algorithm

---

*Dokumentasi ini dibuat untuk NavMate v1.0 - Aplikasi Navigasi Kampus untuk Tunanetra*



