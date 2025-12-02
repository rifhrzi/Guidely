// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'NavMate';

  @override
  String get homeTitle => 'NavMate';

  @override
  String get welcomeTitle => 'Selamat datang di NavMate';

  @override
  String get welcomeSubtitle => 'Navigasi kampus berbasis suara';

  @override
  String get speakDestination => 'Ucapkan Tujuan';

  @override
  String get speakDestinationHint => 'Ketuk dua kali untuk mengucapkan tujuan';

  @override
  String get favorites => 'Favorit';

  @override
  String get help => 'Bantuan';

  @override
  String get recentDestinations => 'Tujuan terbaru';

  @override
  String recentVisitedAt(String time) {
    return 'Terakhir digunakan pukul $time';
  }

  @override
  String get homeVoiceWelcome =>
      'Ucapkan Tujuan untuk mulai bernavigasi. Pintasan dan tujuan terbaru ada di bawah.';

  @override
  String get favoritesActionHint =>
      'Lihat daftar landmark kampus favorit Anda.';

  @override
  String get helpActionHint => 'Dengar tips dan perintah suara NavMate.';

  @override
  String get mapActionHint => 'Buka peta kampus offline.';

  @override
  String get settingsActionHint => 'Atur suara dan preferensi aksesibilitas.';

  @override
  String get recentReopenHint =>
      'Ketuk dua kali untuk menavigasi lagi ke tempat ini.';

  @override
  String navigationProgress(String percent) {
    return '$percent% selesai';
  }

  @override
  String get settings => 'Pengaturan';

  @override
  String get campusMap => 'Peta Kampus';

  @override
  String get speakDestinationTitle => 'Ucapkan Tujuan';

  @override
  String get listening => 'Mendengarkan...';

  @override
  String get sayYourDestination => 'Sebutkan tujuan Anda';

  @override
  String get listenAgain => 'Dengar lagi';

  @override
  String get confirm => 'Konfirmasi';

  @override
  String get confirmTitle => 'Konfirmasi';

  @override
  String didYouSay(Object text) {
    return 'Apakah Anda mengatakan \'$text\'?';
  }

  @override
  String didYouMean(Object name) {
    return 'Apakah maksud Anda: $name';
  }

  @override
  String get no => 'Tidak';

  @override
  String get yes => 'Ya';

  @override
  String get tryAgain => 'Coba lagi';

  @override
  String get confirmDestination => 'Konfirmasi tujuan';

  @override
  String headTowardsName(Object name) {
    return 'Menuju ke $name';
  }

  @override
  String navigateToName(Object name) {
    return 'Navigasi ke $name?';
  }

  @override
  String get sorryNotCatch => 'Maaf, saya tidak menangkapnya';

  @override
  String get micPermissionDenied => 'Izin mikrofon ditolak';

  @override
  String get listeningAgain => 'Mendengarkan lagi';

  @override
  String get navigation => 'Navigasi';

  @override
  String get headTowardsDestination => 'Menuju ke tujuan';

  @override
  String meters(Object count) {
    return '$count meter';
  }

  @override
  String arrivedAt(Object name) {
    return 'Anda telah tiba di $name';
  }

  @override
  String get voiceHintsSetting =>
      'Petunjuk suara (saat TalkBack/VoiceOver mati)';

  @override
  String get clarityModeSetting => 'Mode jelas (TTS lebih lambat dan jelas)';

  @override
  String get screenReader => 'Pembaca layar';

  @override
  String get active => 'Aktif (TalkBack/VoiceOver)';

  @override
  String get inactive => 'Tidak aktif';

  @override
  String get haptics => 'Getaran';

  @override
  String get ttsSpeed => 'Kecepatan TTS';

  @override
  String get testVoice => 'Uji suara';

  @override
  String get talkbackNote =>
      'Catatan: Kecepatan TalkBack/VoiceOver diatur oleh pengaturan aksesibilitas sistem.';

  @override
  String get language => 'Bahasa';

  @override
  String get systemDefault => 'Bawaan sistem';

  @override
  String get indonesian => 'Bahasa Indonesia';

  @override
  String get english => 'Inggris';

  @override
  String get helpBody =>
      'Perintah suara:\n- Ucapkan Tujuan: Sebutkan nama gedung atau tempat.\n- Ulangi: Dengar ulang instruksi terakhir.\n- Batalkan: Hentikan navigasi.\n\nTips:\n- Pegang ponsel tegak untuk akurasi kompas yang lebih baik.\n- Izinkan lokasi presisi saat navigasi.';

  @override
  String get repeatInstruction => 'Ulangi';

  @override
  String get pauseNavigation => 'Jeda';

  @override
  String get resumeNavigation => 'Lanjutkan';

  @override
  String get endNavigation => 'Akhiri';

  @override
  String continueForMeters(Object count) {
    return 'Lanjutkan sejauh $count meter.';
  }

  @override
  String get offRoute => 'Anda tampaknya keluar jalur. Menghitung ulang...';

  @override
  String get gpsSignalLost => 'Sinyal GPS hilang. Tetap diam dan coba lagi.';

  @override
  String get arrivalComplete => 'Anda telah tiba.';

  @override
  String get requestingPermission => 'Meminta izin mikrofon...';

  @override
  String get micPermissionDeniedForever =>
      'Izin mikrofon ditolak secara permanen. Aktifkan di Pengaturan untuk menggunakan input suara.';

  @override
  String get listeningFailed =>
      'Saya tidak memahaminya. Anda bisa mencoba lagi atau ketik saja.';

  @override
  String get openAppSettings => 'Buka Pengaturan';

  @override
  String get typeYourDestination => 'Ketik tujuan Anda';

  @override
  String get enterDestinationHint => 'Masukkan nama gedung atau tempat';

  @override
  String get submit => 'Kirim';
}
