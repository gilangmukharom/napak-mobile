import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';

/// Rombongan simulasi — alat pengembangan.
///
/// Mencoba Trip Bareng sungguhan butuh lima HP dan lima orang di jalan.
/// Server menyediakan lima rekan palsu yang berbaris di belakangmu, lewat
/// jalur yang sama dengan anggota sungguhan.
///
/// Servernya yang memutuskan fitur ini ada atau tidak (`/simulasi/status`):
/// di produksi seluruh rutenya menjawab 404, dan tombolnya tidak pernah
/// muncul di layar.
class SimulasiRepository {
  SimulasiRepository(this._api);

  final ApiClient _api;

  Future<bool> aktif() async {
    try {
      final data = await _api.get<Map<String, dynamic>>('/simulasi/status');
      return data['aktif'] as bool? ?? false;
    } catch (_) {
      // Server lama atau produksi: anggap tidak ada.
      return false;
    }
  }

  Future<bool> berjalan(String tripId) async {
    try {
      final data = await _api.get<Map<String, dynamic>>(
        '/simulasi/rombongan/$tripId',
      );
      return data['berjalan'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> mulai(String tripId, {int jumlah = 5, int jarakM = 50}) async {
    await _api.post<Map<String, dynamic>>(
      '/simulasi/rombongan',
      body: {'tripId': tripId, 'jumlah': jumlah, 'jarakM': jarakM},
    );
  }

  Future<void> berhenti(String tripId) =>
      _api.delete<void>('/simulasi/rombongan/$tripId');
}

final simulasiRepositoryProvider = Provider<SimulasiRepository>(
  (ref) => SimulasiRepository(ref.watch(apiClientProvider)),
);

/// Apakah server mengizinkan simulasi. Ditanyakan sekali per sesi aplikasi.
final simulasiTersediaProvider = FutureProvider<bool>(
  (ref) => ref.watch(simulasiRepositoryProvider).aktif(),
);

/// Apakah rombongan simulasi sedang berjalan di perjalanan ini.
final simulasiBerjalanProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, tripId) async {
    if (!(await ref.watch(simulasiTersediaProvider.future))) return false;
    return ref.watch(simulasiRepositoryProvider).berjalan(tripId);
  },
);
