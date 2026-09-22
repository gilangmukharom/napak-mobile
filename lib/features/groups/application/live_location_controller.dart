import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../recording/application/recording_controller.dart';
import '../../trips/data/trip_models.dart';
import '../data/live_location_service.dart';

final liveLocationServiceProvider = Provider<LiveLocationService>((ref) {
  final service = LiveLocationService(
    alamatDasar: ref.watch(apiClientProvider).alamatDasar,
    ambilToken: ref.watch(tokenStoreProvider).readAccessToken,
  );
  ref.onDispose(service.tutup);
  return service;
});

/// Anggota sebuah Trip Bareng.
final memberListProvider = FutureProvider.autoDispose
    .family<List<TripMember>, String>(
      (ref, tripId) => ref.watch(tripRepositoryProvider).members(tripId),
    );

@immutable
class LiveState {
  const LiveState({
    this.posisi = const {},
    this.tersambung = false,
    this.berbagiSendiri = false,
    this.sinyal = const [],
    this.konvoi,
    this.telepon = const StatusTelepon(),
    this.pesan,
  });

  /// Posisi terakhir tiap anggota, dikunci userId. Hanya ada di memori —
  /// begitu layarnya ditutup, semuanya hilang.
  final Map<String, PosisiLangsung> posisi;

  final bool tersambung;

  /// Apakah kamu sendiri sedang membagikan posisi di sesi ini.
  final bool berbagiSendiri;

  /// Sinyal terbaru dari rombongan, yang terbaru di depan.
  ///
  /// Hanya di memori dan dibatasi jumlahnya. Ini alat koordinasi saat jalan,
  /// bukan riwayat percakapan — menyimpannya berarti membangun chat lewat
  /// pintu belakang, lengkap dengan kewajiban retensi dan penghapusannya.
  final List<SinyalMasuk> sinyal;

  /// Barisan rombongan terakhir. null sampai minimal dua orang berbagi posisi.
  final KabarKonvoi? konvoi;

  /// Telepon rombongan yang sedang berjalan.
  final StatusTelepon telepon;

  final String? pesan;

  LiveState copyWith({
    Map<String, PosisiLangsung>? posisi,
    bool? tersambung,
    bool? berbagiSendiri,
    List<SinyalMasuk>? sinyal,
    KabarKonvoi? konvoi,
    StatusTelepon? telepon,
    String? pesan,
    bool hapusPesan = false,
  }) => LiveState(
    posisi: posisi ?? this.posisi,
    tersambung: tersambung ?? this.tersambung,
    berbagiSendiri: berbagiSendiri ?? this.berbagiSendiri,
    sinyal: sinyal ?? this.sinyal,
    konvoi: konvoi ?? this.konvoi,
    telepon: telepon ?? this.telepon,
    pesan: hapusPesan ? null : (pesan ?? this.pesan),
  );
}

/// Menonton peta bersama satu perjalanan.
///
/// Sambungannya dibuka saat layar Trip Bareng dibuka dan ditutup saat
/// ditinggalkan — itulah gunanya `autoDispose` di sini. Socket yang menganggur
/// sepanjang aplikasi hidup berarti radio HP menyala tanpa alasan.
class LiveLocationController extends Notifier<LiveState> {
  LiveLocationController(this.tripId);

  final String tripId;

  final _langganan = <StreamSubscription<dynamic>>[];
  Timer? _pengirim;

  @override
  LiveState build() {
    final service = ref.watch(liveLocationServiceProvider);

    _langganan.addAll([
      service.posisi.listen((p) {
        state = state.copyWith(posisi: {...state.posisi, p.userId: p});
      }),
      service.tersambung.listen((t) {
        state = state.copyWith(tersambung: t);
      }),
      service.galat.listen((g) {
        state = state.copyWith(pesan: g);
      }),
      service.konvoi.listen((k) {
        // Pengumuman tertinggal dimunculkan sebagai pesan, sekali — server
        // sudah memastikan nama yang sama tidak disebut berulang.
        state = state.copyWith(
          konvoi: k,
          pesan: k.pengumuman.isEmpty ? null : k.pengumuman.join(' '),
        );
      }),
      service.telepon.listen((t) => state = state.copyWith(telepon: t)),
      service.sinyal.listen((m) {
        // Delapan terakhir saja. Yang lebih lama sudah tidak berguna untuk
        // mengoordinasikan apa pun.
        state = state.copyWith(sinyal: [m, ...state.sinyal].take(8).toList());
      }),
    ]);

    ref.onDispose(() {
      for (final l in _langganan) {
        l.cancel();
      }
      _pengirim?.cancel();
      service.putus();
    });

    unawaited(service.tonton(tripId));
    unawaited(_pulihkanBerbagi());
    return const LiveState();
  }

  /// Izin berbagi posisi disimpan di server per sesi. Kalau sudah menyala,
  /// pengirimannya dilanjutkan — controller ini hidup selama layarnya
  /// terbuka, dan pindah dari layar Trip Bareng ke layar rekam tidak boleh
  /// diam-diam menghentikan posisimu padahal izinnya masih menyala.
  Future<void> _pulihkanBerbagi() async {
    try {
      final anggota = await ref.read(tripRepositoryProvider).members(tripId);
      final saya = anggota.where((m) => m.saya).firstOrNull;
      if (!ref.mounted || saya == null || !saya.liveLocationEnabled) return;
      state = state.copyWith(berbagiSendiri: true);
      _mulaiMengirim();
    } catch (_) {
      // Gagal membaca daftar anggota: biarkan mati. Menyalakan diam-diam
      // tanpa kepastian izin itu kebalikan dari yang dijanjikan.
    }
  }

  /// Nyalakan atau matikan berbagi posisi.
  ///
  /// Izinnya disimpan di server per sesi perjalanan, bukan sebagai setelan
  /// global yang menyala diam-diam di perjalanan berikutnya.
  Future<void> aturBerbagi({required bool nyala}) async {
    try {
      final hasil = await ref
          .read(tripRepositoryProvider)
          .setLiveLocation(tripId, enabled: nyala);

      state = state.copyWith(
        berbagiSendiri: hasil,
        pesan: hasil
            ? 'Teman seperjalananmu sekarang bisa melihat posisimu.'
            : 'Posisimu tidak lagi dibagikan.',
      );

      if (hasil) {
        _mulaiMengirim();
      } else {
        _pengirim?.cancel();
        _pengirim = null;
      }

      ref.invalidate(memberListProvider(tripId));
    } catch (error) {
      state = state.copyWith(pesan: error.toString());
    }
  }

  void hapusPesan() => state = state.copyWith(hapusPesan: true);

  /// Kirim sinyal satu ketuk ke rombongan.
  ///
  /// Tidak menunggu balasan server: sinyalnya kembali lewat socket bersama
  /// sinyal orang lain, jadi tampilannya tidak perlu menebak-nebak sendiri.
  void kirimSinyal(Sinyal sinyal) {
    ref
        .read(liveLocationServiceProvider)
        .kirimSinyal(tripId: tripId, sinyal: sinyal);
  }

  /// Kirim posisi tiap 15 detik selama berbagi menyala.
  ///
  /// Yang dikirim adalah posisi terakhir dari perekaman yang sedang berjalan,
  /// jadi tidak ada pembacaan GPS tambahan — radionya sudah menyala untuk
  /// merekam, tidak perlu dinyalakan dua kali.
  void _mulaiMengirim() {
    _pengirim?.cancel();
    _pengirim = Timer.periodic(const Duration(seconds: 15), (_) {
      final rekaman = ref.read(recordingControllerProvider);
      final terakhir = rekaman.latest;
      if (terakhir == null || rekaman.tripId != tripId) return;

      ref
          .read(liveLocationServiceProvider)
          .bagikanPosisi(
            tripId: tripId,
            lat: terakhir.lat,
            lng: terakhir.lng,
            jarakM: rekaman.jarakM,
            moda: rekaman.moda,
          );
    });
  }
}

final liveLocationControllerProvider = NotifierProvider.autoDispose
    .family<LiveLocationController, LiveState, String>(
      LiveLocationController.new,
    );
