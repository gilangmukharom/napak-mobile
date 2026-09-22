import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/intercom_service.dart';

final intercomServiceProvider = Provider<IntercomService>((ref) {
  final service = IntercomService(
    alamatDasar: ref.watch(apiClientProvider).alamatDasar,
    ambilToken: ref.watch(tokenStoreProvider).readAccessToken,
  );
  ref.onDispose(service.tutup);
  return service;
});

@immutable
class IntercomState {
  const IntercomState({
    this.tripId,
    this.menyambung = false,
    this.tersambung = false,
    this.bisu = false,
    this.anggota = const [],
    this.bicara = const {},
    this.sayaBicara = false,
    this.mulaiPada,
    this.pesan,
  });

  /// Ruang suara yang sedang diikuti. null = intercom mati.
  final String? tripId;
  final bool menyambung;
  final bool tersambung;
  final bool bisu;
  final List<AnggotaSuara> anggota;

  /// userId yang suaranya sedang terdengar.
  final Set<String> bicara;
  final bool sayaBicara;

  /// Kapan kamu masuk telepon, untuk penghitung durasi.
  final DateTime? mulaiPada;
  final String? pesan;

  bool get aktif => tripId != null;

  IntercomState copyWith({
    String? tripId,
    bool? menyambung,
    bool? tersambung,
    bool? bisu,
    List<AnggotaSuara>? anggota,
    Set<String>? bicara,
    bool? sayaBicara,
    DateTime? mulaiPada,
    String? pesan,
    bool hapusPesan = false,
  }) => IntercomState(
    tripId: tripId ?? this.tripId,
    menyambung: menyambung ?? this.menyambung,
    tersambung: tersambung ?? this.tersambung,
    bisu: bisu ?? this.bisu,
    anggota: anggota ?? this.anggota,
    bicara: bicara ?? this.bicara,
    sayaBicara: sayaBicara ?? this.sayaBicara,
    mulaiPada: mulaiPada ?? this.mulaiPada,
    pesan: hapusPesan ? null : (pesan ?? this.pesan),
  );
}

/// Intercom Trip Bareng.
///
/// Sengaja **tidak** autoDispose: panggilan tidak boleh putus hanya karena
/// orangnya pindah dari layar rekam ke layar Trip Bareng. Yang mematikannya
/// hanya dua hal — orangnya sendiri mengetuk "Keluar", atau perjalanannya
/// ditutup.
class IntercomController extends Notifier<IntercomState> {
  final _langganan = <StreamSubscription<dynamic>>[];
  Timer? _pemantau;

  @override
  IntercomState build() {
    final service = ref.watch(intercomServiceProvider);

    _langganan.addAll([
      service.anggota.listen((a) => state = state.copyWith(anggota: a)),
      service.tersambung.listen(
        (t) => state = state.copyWith(tersambung: t, menyambung: false),
      ),
      service.galat.listen((g) => state = state.copyWith(pesan: g)),
    ]);

    ref.onDispose(() {
      for (final l in _langganan) {
        l.cancel();
      }
      _pemantau?.cancel();
    });

    return const IntercomState();
  }

  IntercomService get _service => ref.read(intercomServiceProvider);

  /// Masuk ruang suara rombongan. Mikrofon baru diminta di sini — tidak
  /// pernah menyala sebelum orangnya sendiri mengetuk "Gabung".
  Future<void> gabung(String tripId) async {
    if (state.tripId == tripId || state.menyambung) return;

    if (!await _service.mintaIzinMikrofon()) {
      state = state.copyWith(
        pesan:
            'Tourvella butuh izin mikrofon untuk telepon rombongan. Kamu '
            'bisa menyalakannya di Pengaturan.',
      );
      return;
    }

    state = IntercomState(
      tripId: tripId,
      menyambung: true,
      mulaiPada: DateTime.now(),
    );
    await _service.masuk(tripId, bisu: false);

    // Siapa yang sedang bicara, lima kali sedetik. State hanya diganti kalau
    // memang berubah — kalau tidak, layar dibangun ulang 5× per detik untuk
    // hal yang sama.
    _pemantau?.cancel();
    _pemantau = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final bicara = _service.pencampur.yangBicara();
      final saya = _service.sayaBicara;
      if (!setEquals(bicara, state.bicara) || saya != state.sayaBicara) {
        state = state.copyWith(bicara: bicara, sayaBicara: saya);
      }
    });
  }

  void aturBisu(bool bisu) {
    if (!state.aktif) return;
    _service.aturBisu(bisu);
    state = state.copyWith(bisu: bisu, sayaBicara: bisu ? false : null);
  }

  Future<void> keluar() async {
    _pemantau?.cancel();
    _pemantau = null;
    await _service.keluar();
    state = const IntercomState();
  }

  void hapusPesan() => state = state.copyWith(hapusPesan: true);
}

final intercomControllerProvider =
    NotifierProvider<IntercomController, IntercomState>(
      IntercomController.new,
    );
