import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpan token sesi.
///
/// Memakai Keystore (Android) dan Keychain (iOS), bukan SharedPreferences —
/// kunci yang membuka seluruh riwayat perjalanan seseorang tidak pantas
/// disimpan dalam file biasa.
class TokenStore {
  TokenStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessKey = 'napak.access_token';
  static const _refreshKey = 'napak.refresh_token';
  static const _nameKey = 'napak.user_name';

  Future<String?> readAccessToken() => _storage.read(key: _accessKey);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);
  Future<String?> readName() => _storage.read(key: _nameKey);

  /// Nama sapaan berganti saat profil diubah.
  Future<void> saveName(String name) =>
      _storage.write(key: _nameKey, value: name);

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? name,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
    if (name != null) {
      await _storage.write(key: _nameKey, value: name);
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  /// Dipanggil saat keluar. Tidak menyisakan apa pun di perangkat.
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _nameKey);
  }
}
