import 'dart:io';

/// Setelan yang berbeda antar lingkungan.
abstract final class NapakConfig {
  /// Alamat backend.
  ///
  /// Emulator Android tidak bisa menyebut "localhost" — itu merujuk ke emulator
  /// itu sendiri, bukan ke komputer yang menjalankannya. 10.0.2.2 adalah jalan
  /// tembusnya.
  ///
  /// **iPhone atau iPad sungguhan tidak punya jalan tembus seperti itu.**
  /// "localhost" di sana berarti HP-nya sendiri, dan backend tidak ada di
  /// situ. Sebutkan alamat LAN komputer yang menjalankan backend:
  ///
  ///   flutter run --dart-define=NAPAK_API_URL=http://192.168.1.10:3000/api
  ///
  /// Simulator iOS ikut memakai jaringan Mac-nya, jadi "localhost" hanya jalan
  /// kalau backend-nya memang di Mac yang sama.
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('NAPAK_API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    return 'http://localhost:3000/api';
  }

  /// Gaya peta Napak.
  ///
  /// Bawaannya diambil dari backend, bukan ditanam di aplikasi: paletnya bisa
  /// diperbaiki tanpa menunggu orang memperbarui aplikasinya, dan kunci
  /// penyedia tile tidak ikut masuk ke dalam APK.
  ///
  /// Saat mengembangkan tanpa tile server, pakai gaya demo MapLibre:
  ///   flutter run --dart-define=NAPAK_MAP_STYLE=https://demotiles.maplibre.org/style.json
  static String get mapStyleUrl {
    const fromEnv = String.fromEnvironment('NAPAK_MAP_STYLE');
    if (fromEnv.isNotEmpty) return fromEnv;
    return '$apiBaseUrl/map/style';
  }

  /// Jarak minimal (meter) sebelum sebuah titik baru layak direkam.
  ///
  /// Berdiam di lampu merah tidak perlu menghasilkan puluhan titik kembar.
  /// Ini penghemat baterai sekaligus penghemat cerita.
  static const minimumDistanceMeters = 25;

  /// Jeda antar pembacaan lokasi saat merekam.
  static const trackingInterval = Duration(seconds: 30);

  /// Titik dikirim ke server per rombongan sebesar ini, bukan satu-satu.
  static const syncBatchSize = 200;
}
