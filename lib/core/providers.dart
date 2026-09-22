import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/recording/data/local_database.dart';
import '../features/trips/data/trip_repository.dart';
import 'network/api_client.dart';
import 'storage/token_store.dart';

/// Akar dependensi Tourvella. Semua yang berumur panjang dirakit di sini supaya
/// mudah diganti saat menulis test.
// Bawaan flutter_secure_storage 11 sudah Keystore + AES-GCM dengan pembungkus
// kunci RSA-OAEP. Tidak ada opsi yang perlu dinyalakan sendiri.
final Provider<FlutterSecureStorage> secureStorageProvider =
    Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

final Provider<TokenStore> tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(ref.watch(secureStorageProvider)),
);

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    ref.watch(tokenStoreProvider),
    onSignedOut: () async {
      // Refresh token sudah tidak sah. Bersihkan sesi supaya router
      // memulangkan pengguna ke halaman masuk.
      await ref.read(tokenStoreProvider).clear();
      ref.invalidate(sessionProvider);
    },
  );
});

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
      (ref) => AuthRepository(
        ref.watch(apiClientProvider),
        ref.watch(tokenStoreProvider),
      ),
    );

final Provider<TripRepository> tripRepositoryProvider =
    Provider<TripRepository>(
      (ref) => TripRepository(ref.watch(apiClientProvider)),
    );

final Provider<TourvellaLocalDatabase> localDatabaseProvider =
    Provider<TourvellaLocalDatabase>((ref) {
      final db = TourvellaLocalDatabase();
      ref.onDispose(db.close);
      return db;
    });

/// Apakah ada sesi yang masih tersimpan di perangkat.
final FutureProvider<bool> sessionProvider = FutureProvider<bool>(
  (ref) => ref.watch(authRepositoryProvider).hasSession(),
);

/// Nama sapaan yang tersimpan, untuk salam di beranda.
final FutureProvider<String?> savedNameProvider = FutureProvider<String?>(
  (ref) => ref.watch(authRepositoryProvider).savedName(),
);

/// Berapa jejak yang masih menunggu sinyal untuk dikirim.
final StreamProvider<int> pendingPointCountProvider = StreamProvider<int>(
  (ref) => ref.watch(localDatabaseProvider).watchPendingCount(),
);
