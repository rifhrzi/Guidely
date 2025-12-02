# OUTLINE SLIDE PRESENTASI SKRIPSI

## NavMate - Aplikasi Navigasi Kampus Berbasis Suara untuk Tunanetra

---

## SLIDE 1: COVER

```
NAVMATE
Aplikasi Navigasi Kampus Berbasis Suara
untuk Penyandang Tunanetra

Disusun oleh:
[Nama Anda]
[NIM]

Pembimbing:
[Nama Dosen Pembimbing]

[Logo Universitas]
[Nama Fakultas/Program Studi]
[Tahun]
```

---

## SLIDE 2: LATAR BELAKANG

**Poin-poin:**

- Penyandang tunanetra memiliki keterbatasan dalam mobilitas mandiri
- Aplikasi navigasi komersial (Google Maps, dll) tidak dioptimalkan untuk tunanetra
- Lingkungan kampus membutuhkan navigasi yang presisi dan aman
- Kebutuhan akan aplikasi berbasis suara dengan operasi offline

**Visual:** Gambar ilustrasi tunanetra atau statistik disabilitas di Indonesia

---

## SLIDE 3: RUMUSAN MASALAH

```
1. Bagaimana mengembangkan aplikasi navigasi yang
   aksesibel untuk penyandang tunanetra?

2. Bagaimana mengimplementasikan teknologi
   Speech-to-Text dan Text-to-Speech untuk
   interaksi berbasis suara?

3. Bagaimana membangun sistem navigasi offline
   menggunakan peta kampus lokal?
```

---

## SLIDE 4: TUJUAN PENELITIAN

```
✓ Mengembangkan aplikasi navigasi aksesibel
  menggunakan framework Flutter

✓ Mengimplementasikan voice input/output
  untuk interaksi hands-free

✓ Membangun navigasi offline dengan
  peta kampus berbasis MBTiles

✓ Menyediakan panduan navigasi dengan
  instruksi verbal yang jelas
```

---

## SLIDE 5: MANFAAT PENELITIAN

**Bagi Pengguna:**

- Kemandirian bernavigasi di kampus
- Akses informasi lokasi real-time
- Pengalaman navigasi yang aman

**Bagi Institusi:**

- Mendukung inklusivitas kampus
- Program universitas ramah disabilitas

---

## SLIDE 6: TINJAUAN PUSTAKA

**Konsep yang Digunakan:**
| Konsep | Penjelasan |
|--------|------------|
| Aksesibilitas Digital | WCAG 2.1 Guidelines |
| Speech Recognition | Speech-to-Text Technology |
| Text-to-Speech | Speech Synthesis |
| Offline Navigation | Local Map Tiles |
| Haversine Formula | Distance Calculation |

---

## SLIDE 7: METODOLOGI PENELITIAN

**Model: RAD (Rapid Application Development)**

```
┌────────────────────┐
│ 1. REQUIREMENTS    │ → Analisis kebutuhan, studi literatur,
│    PLANNING        │   survey kampus FKIP UNTIRTA
└─────────┬──────────┘
          ▼
┌────────────────────┐
│ 2. USER DESIGN     │ → UI/UX design, wireframe, validasi
│                    │   dengan pengguna tunanetra
└─────────┬──────────┘
          ▼
┌────────────────────┐ ◄─────┐
│ 3. RAPID           │       │ Iterasi
│    CONSTRUCTION    │       │ Cepat
└─────────┬──────────┘       │
          ▼                  │
┌────────────────────┐       │
│ 4. USER FEEDBACK   │ ──────┘
└─────────┬──────────┘
          ▼
┌────────────────────┐
│ 5. CUTOVER         │ → Deployment, dokumentasi
└────────────────────┘
```

**Mengapa RAD?**

- Prototyping cepat untuk validasi dengan tunanetra
- Feedback iteratif dari pengguna
- Waktu pengembangan yang efisien

---

## SLIDE 8: ARSITEKTUR SISTEM

```
┌─────────────────────────────────┐
│     PRESENTATION LAYER          │
│  Home | Navigation | Settings   │
├─────────────────────────────────┤
│     CORE SERVICES LAYER         │
│  TTS | STT | Location | Map     │
├─────────────────────────────────┤
│     DATA LAYER                  │
│  MBTiles | Landmarks | GeoJSON  │
└─────────────────────────────────┘
```

---

## SLIDE 9: TEKNOLOGI YANG DIGUNAKAN

| Teknologi      | Fungsi                   |
| -------------- | ------------------------ |
| Flutter        | Cross-platform framework |
| Dart           | Programming language     |
| flutter_map    | Map rendering            |
| speech_to_text | Voice recognition        |
| flutter_tts    | Text-to-speech           |
| geolocator     | GPS tracking             |
| sqlite3        | MBTiles database         |

---

## SLIDE 10: FITUR UTAMA - VOICE INPUT

**Speak Destination:**

```
Pengguna → [Tekan Mikrofon] → Ucapkan tujuan
                ↓
            "Gedung A FKIP"
                ↓
        [Dialog Konfirmasi]
                ↓
         Mulai Navigasi
```

**Visual:** Screenshot halaman voice destination

---

## SLIDE 11: FITUR UTAMA - VOICE OUTPUT

**Text-to-Speech Features:**

- Announcements navigasi real-time
- Kecepatan bicara adjustable (0.4 - 1.2)
- Clarity Mode untuk artikulasi jelas
- Dukungan Bahasa Indonesia & Inggris

**Visual:** Screenshot settings TTS

---

## SLIDE 12: FITUR UTAMA - NAVIGASI

**Turn-by-Turn Navigation:**

- Live distance tracking (meter)
- Progress bar perjalanan
- Indikator belokan dengan ikon
- Arrival detection (radius 8m)

**Instruksi:**

- "Jalan lurus 50 meter"
- "Belok kiri di depan"
- "Anda telah sampai di tujuan"

**Visual:** Screenshot navigation page

---

## SLIDE 13: FITUR UTAMA - PETA OFFLINE

**Offline Map Technology:**

- Format: MBTiles (SQLite-based)
- Overlay: Gedung, Jalan, POI
- No internet required

**Lokasi FKIP UNTIRTA:**

- Gedung A, B, C FKIP
- Kantin, Masjid, Rusun

**Visual:** Screenshot campus map

---

## SLIDE 14: FITUR AKSESIBILITAS

| Fitur              | Implementasi               |
| ------------------ | -------------------------- |
| Large Touch Target | Min 72dp buttons           |
| Screen Reader      | TalkBack/VoiceOver support |
| Haptic Feedback    | Vibration patterns         |
| Voice Hints        | TTS fallback               |
| High Contrast      | WCAG 4.5:1 ratio           |
| Semantic Labels    | All interactive elements   |

---

## SLIDE 15: IMPLEMENTASI - SPEECH TO TEXT

```dart
// Listening for voice input
await _speech.listen(
  onResult: (result) => _handleResult(result),
  localeId: 'id-ID',  // Bahasa Indonesia
  listenOptions: SpeechListenOptions(
    partialResults: true,
    listenMode: ListenMode.dictation,
  ),
);
```

---

## SLIDE 16: IMPLEMENTASI - NAVIGATION

```dart
// Calculate distance using Haversine formula
double haversineMeters(LatLng a, LatLng b) {
  const R = 6371000.0; // Earth radius (m)
  final dLat = _toRadians(b.lat - a.lat);
  final dLon = _toRadians(b.lng - a.lng);
  // ... calculation ...
  return R * c;
}

// Announce when approaching destination
if (distance < 8) {
  tts.speak("Anda telah sampai");
  haptics.arrivedPattern();
}
```

---

## SLIDE 17: PENGUJIAN

**Unit Testing:**
| Test Case | Status |
|-----------|--------|
| Destination matching | ✅ Pass |
| Navigation distance | ✅ Pass |
| Widget rendering | ✅ Pass |

**Accessibility Testing:**
| Kriteria | Hasil |
|----------|-------|
| Touch target | 72dp ✅ |
| Color contrast | 7:1 ✅ |
| Screen reader | ✅ |

---

## SLIDE 18: DEMO APLIKASI

```
[Slot untuk video demo atau live demo]

Skenario Demo:
1. Buka aplikasi NavMate
2. Tekan "Speak Destination"
3. Ucapkan "Gedung A FKIP"
4. Konfirmasi tujuan
5. Ikuti navigasi
6. Sampai di tujuan
```

---

## SLIDE 19: HASIL & PEMBAHASAN

**Keberhasilan:**
✅ Voice input berhasil mengenali tujuan dalam Bahasa Indonesia
✅ TTS memberikan panduan yang jelas dan dapat diatur kecepatannya
✅ Navigasi real-time dengan akurasi GPS < 5 meter
✅ Peta offline berfungsi tanpa koneksi internet
✅ Haptic feedback responsif pada setiap event

**Visual:** Tabel perbandingan sebelum/sesudah atau grafik hasil

---

## SLIDE 20: BATASAN PENELITIAN

```
1. Pengujian terbatas pada kampus FKIP UNTIRTA

2. Routing menggunakan straight-line estimation
   (A* pathfinding dalam pengembangan)

3. Belum ada deteksi halangan/obstacle

4. Membutuhkan akurasi GPS yang baik
```

---

## SLIDE 21: KESIMPULAN

```
1. NavMate BERHASIL dikembangkan sebagai aplikasi
   navigasi berbasis suara untuk tunanetra

2. Integrasi STT & TTS memungkinkan
   interaksi hands-free yang efektif

3. Pendekatan offline-first menjamin
   operasi tanpa internet

4. Fitur aksesibilitas sesuai standar WCAG
   dan kompatibel dengan screen reader
```

---

## SLIDE 22: SARAN PENGEMBANGAN

**Future Work:**

1. 🗺️ Implementasi A\* Routing untuk navigasi akurat
2. 📡 Integrasi Bluetooth Beacons untuk indoor navigation
3. 🚧 Obstacle detection dengan sensor/kamera
4. 🏫 Ekspansi ke multi-campus support
5. ⌚ Integrasi smartwatch/wearable devices

---

## SLIDE 23: DAFTAR PUSTAKA

```
1. Flutter Documentation (docs.flutter.dev)
2. WCAG 2.1 - Web Content Accessibility Guidelines
3. Google Material Design 3
4. OpenStreetMap Data Specification
5. [Tambahkan referensi jurnal/buku lainnya]
```

---

## SLIDE 24: TERIMA KASIH

```
TERIMA KASIH

NavMate
"Membantu Tunanetra Bernavigasi dengan Mandiri"

[QR Code repository/download]

Contact:
[Email]
[GitHub: repository link]
```

---

## TIPS PRESENTASI

### Durasi per Slide:

- Cover: 30 detik
- Latar Belakang: 1-2 menit
- Metodologi: 2-3 menit
- Fitur Utama: 3-5 menit
- Implementasi: 2-3 menit
- Demo: 3-5 menit
- Kesimpulan: 1-2 menit

### Visual yang Perlu Disiapkan:

1. Screenshot aplikasi (Home, Navigation, Map, Settings)
2. Video demo navigasi (2-3 menit)
3. Diagram arsitektur
4. Flowchart alur kerja
5. Tabel hasil pengujian

### Pertanyaan yang Mungkin Muncul:

1. "Bagaimana jika GPS tidak akurat?"
   → Aplikasi menampilkan warning dan tetap memberikan estimasi jarak

2. "Apakah bisa digunakan di kampus lain?"
   → Ya, dengan menyiapkan MBTiles dan landmarks baru

3. "Bagaimana dengan navigasi indoor?"
   → Saat ini fokus outdoor, indoor dengan beacons dalam roadmap

4. "Apa kelebihan dibanding Google Maps?"
   → Voice-first design, offline, accessibility-focused

5. "Library speech recognition apa yang dipakai?"
   → speech_to_text dengan engine platform native (Google/Apple)
