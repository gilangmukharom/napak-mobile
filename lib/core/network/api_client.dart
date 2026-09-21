import 'package:dio/dio.dart';

import '../config/napak_config.dart';
import '../storage/token_store.dart';

/// Kesalahan yang sudah berbentuk kalimat yang layak dibaca pengguna.
///
/// Backend Napak sudah mengirim pesan dalam Bahasa Indonesia yang hangat, jadi
/// tugas kelas ini hanya mengambilnya — bukan menggantinya dengan "Error 400".
class NapakException implements Exception {
  NapakException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Klien HTTP ke backend Napak.
///
/// Menyisipkan access token, dan saat token itu kedaluwarsa, menukar refresh
/// token lalu mengulang permintaannya sekali — supaya pengguna tidak tiba-tiba
/// terlempar ke halaman masuk di tengah perjalanan.
class ApiClient {
  ApiClient(this._tokenStore, {Dio? dio, this.onSignedOut})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: NapakConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              contentType: 'application/json',
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuth'] != true) {
            final token = await _tokenStore.readAccessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final shouldRefresh =
              error.response?.statusCode == 401 &&
              error.requestOptions.extra['retried'] != true &&
              error.requestOptions.extra['skipAuth'] != true;

          if (!shouldRefresh) {
            return handler.next(error);
          }

          final refreshed = await _refreshSession();
          if (!refreshed) {
            await onSignedOut?.call();
            return handler.next(error);
          }

          try {
            final options = error.requestOptions;
            options.extra['retried'] = true;
            final token = await _tokenStore.readAccessToken();
            options.headers['Authorization'] = 'Bearer $token';
            final response = await _dio.fetch<dynamic>(options);
            return handler.resolve(response);
          } on DioException catch (retryError) {
            return handler.next(retryError);
          }
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStore _tokenStore;

  /// Dipanggil saat refresh token sudah tidak sah dan sesinya harus dilepas.
  final Future<void> Function()? onSignedOut;

  Future<bool> _refreshSession() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {'skipAuth': true}),
      );
      final data = response.data;
      if (data == null) return false;

      await _tokenStore.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return true;
    } on DioException {
      return false;
    }
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _send<T>(() => _dio.get<T>(path, queryParameters: query));

  Future<T> post<T>(String path, {Object? body, bool skipAuth = false}) =>
      _send<T>(
        () => _dio.post<T>(
          path,
          data: body,
          options: Options(extra: {'skipAuth': skipAuth}),
        ),
      );

  Future<T> patch<T>(String path, {Object? body}) =>
      _send<T>(() => _dio.patch<T>(path, data: body));

  Future<T> put<T>(String path, {Object? body}) =>
      _send<T>(() => _dio.put<T>(path, data: body));

  Future<T> delete<T>(String path, {Object? body}) =>
      _send<T>(() => _dio.delete<T>(path, data: body));

  /// Unduh berkas biner (video hasil render) langsung ke disk.
  ///
  /// Tidak lewat [_send] karena isinya bukan JSON, dan menahan video puluhan
  /// megabyte di memori sebelum menulisnya ke disk tidak ada gunanya.
  Future<void> unduhKeBerkas(
    String path,
    String tujuan, {
    void Function(int terkirim, int total)? kemajuan,
  }) async {
    try {
      await _dio.download(path, tujuan, onReceiveProgress: kemajuan);
    } on DioException catch (error) {
      throw NapakException(
        _messageFrom(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  /// Alamat dasar backend — dibutuhkan klien WebSocket, yang tidak lewat Dio.
  String get alamatDasar => _dio.options.baseUrl;

  Future<T> _send<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      return response.data as T;
    } on DioException catch (error) {
      throw NapakException(
        _messageFrom(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  String _messageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      final message = data['message'];
      // class-validator mengirim daftar pesan saat beberapa field bermasalah.
      if (message is List && message.isNotEmpty) {
        return message.first.toString();
      }
      return message.toString();
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'Sambungannya lambat. Jejakmu tetap tersimpan di HP, nanti dikirim lagi.',
      DioExceptionType.connectionError =>
        'Belum ada sambungan. Napak akan menyusulkan jejakmu begitu sinyal kembali.',
      _ => 'Ada yang tidak beres. Coba lagi sebentar lagi ya.',
    };
  }
}
