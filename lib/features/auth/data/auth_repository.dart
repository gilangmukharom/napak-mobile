import '../../../core/network/api_client.dart';
import '../../../core/storage/token_store.dart';

class AuthSession {
  const AuthSession({
    required this.name,
    required this.phoneNumber,
    required this.isNewUser,
    required this.message,
  });

  final String name;
  final String phoneNumber;
  final bool isNewUser;
  final String message;
}

class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  /// Minta kode masuk. Mengembalikan berapa lama kodenya berlaku, supaya
  /// layar berikutnya bisa menghitung mundur dengan jujur.
  Future<Duration> requestCode(String phoneNumber) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/otp/request',
      body: {'phoneNumber': phoneNumber},
      skipAuth: true,
    );
    return Duration(seconds: data['expiresInSeconds'] as int? ?? 300);
  }

  Future<AuthSession> verifyCode({
    required String phoneNumber,
    required String code,
    String? name,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/otp/verify',
      body: {
        'phoneNumber': phoneNumber,
        'code': code,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      },
      skipAuth: true,
    );

    final user = data['user'] as Map<String, dynamic>;
    await _tokens.save(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      name: user['name'] as String,
    );

    return AuthSession(
      name: user['name'] as String,
      phoneNumber: user['phoneNumber'] as String,
      isNewUser: data['isNewUser'] as bool? ?? false,
      message: data['message'] as String? ?? 'Selamat datang.',
    );
  }

  Future<bool> hasSession() async => (await _tokens.readAccessToken()) != null;

  Future<String?> savedName() => _tokens.readName();

  Future<void> simpanNama(String nama) => _tokens.saveName(nama);

  /// Keluar. Refresh token dicabut di server, lalu jejaknya di perangkat dihapus.
  Future<void> signOut() async {
    final refresh = await _tokens.readRefreshToken();
    if (refresh != null) {
      try {
        await _api.post<Map<String, dynamic>>(
          '/auth/logout',
          body: {'refreshToken': refresh},
          skipAuth: true,
        );
      } on NapakException {
        // Servernya tidak terjangkau; token lokal tetap harus dibuang.
      }
    }
    await _tokens.clear();
  }

  /// Hapus akun beserta seluruh jejak perjalanan, permanen.
  Future<String> deleteAccount(String confirmPhoneNumber) async {
    final data = await _api.delete<Map<String, dynamic>>(
      '/me',
      body: {'confirmPhoneNumber': confirmPhoneNumber},
    );
    await _tokens.clear();
    return data['message'] as String? ?? 'Akunmu sudah dihapus sepenuhnya.';
  }
}
