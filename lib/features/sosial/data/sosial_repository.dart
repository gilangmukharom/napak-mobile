import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import 'sosial_models.dart';

/// Teman, undangan, inbox, kartu pos, dan Jejak Nusantara.
class SosialRepository {
  SosialRepository(this._api);

  final ApiClient _api;

  // --- Teman ---

  Future<List<Teman>> daftarTeman() async {
    final data = await _api.get<List<dynamic>>('/teman');
    return [for (final t in data) Teman.fromJson(t as Map<String, dynamic>)];
  }

  Future<String> kodeSaya() async {
    final data = await _api.get<Map<String, dynamic>>('/teman/kode');
    return data['friendCode'] as String;
  }

  Future<HasilCari> cari(String kode) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/teman/cari',
      query: {'kode': kode},
    );
    return HasilCari.fromJson(data);
  }

  /// Mengembalikan kalimat dari server, siap ditampilkan.
  Future<String> ajak(String kode) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/teman/ajak',
      body: {'kode': kode},
    );
    return data['message'] as String;
  }

  Future<List<PermintaanTeman>> permintaanMasuk() async {
    final data = await _api.get<List<dynamic>>('/teman/permintaan');
    return [
      for (final p in data)
        PermintaanTeman.dariMasuk(p as Map<String, dynamic>),
    ];
  }

  Future<List<PermintaanTeman>> permintaanTerkirim() async {
    final data = await _api.get<List<dynamic>>('/teman/terkirim');
    return [
      for (final p in data)
        PermintaanTeman.dariTerkirim(p as Map<String, dynamic>),
    ];
  }

  Future<String> terima(String permintaanId) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/teman/permintaan/$permintaanId/terima',
    );
    return data['message'] as String;
  }

  Future<void> tolak(String permintaanId) =>
      _api.post<dynamic>('/teman/permintaan/$permintaanId/tolak');

  Future<void> putuskan(String temanId) =>
      _api.delete<dynamic>('/teman/$temanId');

  // --- Undangan ---

  Future<String> undang(String tripId, List<String> temanIds) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/trips/$tripId/undang',
      body: {'temanIds': temanIds},
    );
    return data['message'] as String;
  }

  Future<List<UndanganTrip>> undanganMasuk() async {
    final data = await _api.get<List<dynamic>>('/undangan');
    return [
      for (final u in data) UndanganTrip.fromJson(u as Map<String, dynamic>),
    ];
  }

  /// Mengembalikan id perjalanan kalau ikut, supaya bisa langsung dibuka.
  Future<({String pesan, String? tripId})> jawabUndangan(
    String undanganId, {
    required bool ikut,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/undangan/$undanganId/jawab',
      body: {'ikut': ikut},
    );
    return (
      pesan: data['message'] as String,
      tripId: data['tripId'] as String?,
    );
  }

  // --- Inbox ---

  Future<List<Kabar>> inbox() async {
    final data = await _api.get<List<dynamic>>('/inbox');
    return [for (final k in data) Kabar.fromJson(k as Map<String, dynamic>)];
  }

  Future<int> jumlahBelumDibaca() async {
    final data = await _api.get<Map<String, dynamic>>('/inbox/jumlah');
    return data['jumlah'] as int? ?? 0;
  }

  Future<void> tandaiDibaca(String kabarId) =>
      _api.post<dynamic>('/inbox/$kabarId/dibaca');

  Future<void> tandaiSemuaDibaca() => _api.post<dynamic>('/inbox/dibaca-semua');

  Future<void> buangKabar(String kabarId) =>
      _api.delete<dynamic>('/inbox/$kabarId');

  // --- Kartu pos ---

  Future<String> kirimKartuPos({
    required String titikId,
    required String penerimaId,
    String? pesan,
    String? tempat,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/kartu-pos',
      body: {
        'titikId': titikId,
        'penerimaId': penerimaId,
        if (pesan != null && pesan.trim().isNotEmpty) 'pesan': pesan.trim(),
        if (tempat != null && tempat.trim().isNotEmpty) 'tempat': tempat.trim(),
      },
    );
    return data['message'] as String;
  }

  Future<List<KartuPos>> kartuPosMasuk() async {
    final data = await _api.get<List<dynamic>>('/kartu-pos');
    return [for (final k in data) KartuPos.fromJson(k as Map<String, dynamic>)];
  }

  Future<List<KartuPos>> kartuPosTerkirim() async {
    final data = await _api.get<List<dynamic>>('/kartu-pos/terkirim');
    return [for (final k in data) KartuPos.fromJson(k as Map<String, dynamic>)];
  }

  Future<KartuPos> kartuPos(String id) async {
    final data = await _api.get<Map<String, dynamic>>('/kartu-pos/$id');
    return KartuPos.fromJson(data);
  }

  Future<void> buangKartuPos(String id) =>
      _api.delete<dynamic>('/kartu-pos/$id');

  // --- Jejak Nusantara ---

  Future<JejakNusantara> jejakNusantara() async {
    final data = await _api.get<Map<String, dynamic>>('/recap/jejak-nusantara');
    return JejakNusantara.fromJson(data);
  }
}

final sosialRepositoryProvider = Provider<SosialRepository>(
  (ref) => SosialRepository(ref.watch(apiClientProvider)),
);

final daftarTemanProvider = FutureProvider.autoDispose<List<Teman>>(
  (ref) => ref.watch(sosialRepositoryProvider).daftarTeman(),
);

final permintaanMasukProvider =
    FutureProvider.autoDispose<List<PermintaanTeman>>(
      (ref) => ref.watch(sosialRepositoryProvider).permintaanMasuk(),
    );

final permintaanTerkirimProvider =
    FutureProvider.autoDispose<List<PermintaanTeman>>(
      (ref) => ref.watch(sosialRepositoryProvider).permintaanTerkirim(),
    );

final kodeSayaProvider = FutureProvider.autoDispose<String>(
  (ref) => ref.watch(sosialRepositoryProvider).kodeSaya(),
);

final inboxProvider = FutureProvider.autoDispose<List<Kabar>>(
  (ref) => ref.watch(sosialRepositoryProvider).inbox(),
);

final undanganMasukProvider = FutureProvider.autoDispose<List<UndanganTrip>>(
  (ref) => ref.watch(sosialRepositoryProvider).undanganMasuk(),
);

/// Angka di lencana inbox.
///
/// Tidak `autoDispose`: lencananya hidup di beranda dan dibaca ulang tiap
/// beranda muncul lagi. Menariknya lewat polling di latar belakang berarti
/// radio HP menyala untuk sebuah angka — yang dilakukan cuma membaca ulang
/// saat memang dilihat.
final jumlahKabarProvider = FutureProvider<int>(
  (ref) => ref.watch(sosialRepositoryProvider).jumlahBelumDibaca(),
);

final kartuPosMasukProvider = FutureProvider.autoDispose<List<KartuPos>>(
  (ref) => ref.watch(sosialRepositoryProvider).kartuPosMasuk(),
);

final kartuPosTerkirimProvider = FutureProvider.autoDispose<List<KartuPos>>(
  (ref) => ref.watch(sosialRepositoryProvider).kartuPosTerkirim(),
);

final kartuPosProvider = FutureProvider.autoDispose.family<KartuPos, String>(
  (ref, id) => ref.watch(sosialRepositoryProvider).kartuPos(id),
);

final jejakNusantaraProvider = FutureProvider.autoDispose<JejakNusantara>(
  (ref) => ref.watch(sosialRepositoryProvider).jejakNusantara(),
);
