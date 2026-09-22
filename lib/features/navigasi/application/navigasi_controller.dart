import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';

import '../data/navigasi_data.dart';
import 'penjejak_rute.dart';
import 'ucapan_navigasi.dart';

@immutable
class NavigasiState {
  const NavigasiState({
    this.rute,
    this.keadaan,
    this.bisu = false,
    this.menghitungUlang = false,
    this.pesan,
  });

  final Rute? rute;
  final KeadaanNavigasi? keadaan;
  final bool bisu;
  final bool menghitungUlang;
  final String? pesan;

  bool get aktif => rute != null;

  /// Manuver yang sedang dituju.
  LangkahRute? get langkah {
    final r = rute;
    final k = keadaan;
    if (r == null || k == null) return null;
    if (k.indeksLangkah >= r.langkah.length) return null;
    return r.langkah[k.indeksLangkah];
  }

  NavigasiState copyWith({
    Rute? rute,
    KeadaanNavigasi? keadaan,
    bool? bisu,
    bool? menghitungUlang,
    String? pesan,
    bool hapusPesan = false,
    bool berhenti = false,
  }) => NavigasiState(
    rute: berhenti ? null : (rute ?? this.rute),
    keadaan: berhenti ? null : (keadaan ?? this.keadaan),
    bisu: bisu ?? this.bisu,
    menghitungUlang: menghitungUlang ?? this.menghitungUlang,
    pesan: hapusPesan ? null : (pesan ?? this.pesan),
  );
}

/// Navigasi suara ke tujuan yang dipilih.
///
/// Tiga hal yang membuatnya terasa seperti navigasi sungguhan, dan
/// masing-masing ada alasannya:
///
/// 1. **Jarak dihitung menyusuri rute**, bukan garis lurus ([PenjejakRute]).
/// 2. **Suara empat kali per manuver** (1 km, 400 m, 120 m, tepat di
///    belokan), bukan terus-menerus. Navigasi yang cerewet akan dimatikan
///    orang, dan navigasi yang mati tidak menolong siapa pun.
/// 3. **Keluar jalur dihitung ulang sendiri**, setelah tiga pembacaan GPS
///    berturut-turut jauh dari rute — bukan satu, supaya satu lompatan GPS
///    di bawah jembatan tidak memicu hitung ulang.
///
/// Suaranya menumpang sesi audio yang sama dengan telepon rombongan
/// (`playAndRecord` + `duckOthers`): saat Tourvella bilang "belok kiri",
/// suara teman mengecil sebentar, bukan terputus.
class NavigasiController extends Notifier<NavigasiState> {
  final _tts = FlutterTts();
  StreamSubscription<Position>? _posisi;
  PenjejakRute? _penjejak;
  final _sudahDiumumkan = <double>{};
  int _indeksTerakhir = -1;
  int _keluarJalurBerturut = 0;
  bool _ttsSiap = false;

  @override
  NavigasiState build() {
    ref.onDispose(() {
      _posisi?.cancel();
      _tts.stop();
    });
    return const NavigasiState();
  }

  Future<void> _siapkanTts() async {
    if (_ttsSiap) return;
    await _tts.setLanguage('id-ID');
    await _tts.setSpeechRate(Platform.isIOS ? 0.5 : 0.95);
    await _tts.setVolume(1);
    if (Platform.isIOS) {
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playAndRecord,
        [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          // Suara teman di telepon rombongan mengecil sebentar, tidak
          // terputus.
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    }
    _ttsSiap = true;
  }

  Future<void> _ucap(String kalimat) async {
    if (state.bisu) return;
    try {
      await _siapkanTts();
      await _tts.stop();
      await _tts.speak(kalimat);
    } catch (error) {
      debugPrint('Suara navigasi gagal: $error');
    }
  }

  /// Mulai menavigasi rute yang sudah dihitung.
  Future<void> mulai(Rute rute) async {
    _penjejak = PenjejakRute(rute);
    _sudahDiumumkan.clear();
    _indeksTerakhir = -1;
    _keluarJalurBerturut = 0;
    state = NavigasiState(rute: rute, bisu: state.bisu);

    await _ucap(rute.ringkasan);
    await _posisi?.cancel();
    _posisi =
        Geolocator.getPositionStream(
          // Navigasi butuh pembaruan jauh lebih rapat daripada perekaman
          // jejak (25 m): belokan bisa terlewat di antara dua pembacaan.
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 5,
          ),
        ).listen(
          (p) => _perbarui(p.latitude, p.longitude),
          onError: (Object _) {},
        );
  }

  void _perbarui(double lat, double lng) {
    final penjejak = _penjejak;
    final rute = state.rute;
    if (penjejak == null || rute == null) return;

    final keadaan = penjejak.perbarui(
      lat,
      lng,
      dariLangkah: state.keadaan?.indeksLangkah ?? 0,
    );
    state = state.copyWith(keadaan: keadaan);

    if (keadaan.sampai) {
      unawaited(_ucap('Sampai di tujuan. Selamat, perjalananmu sudah sampai.'));
      unawaited(berhenti(diam: true));
      return;
    }

    // Keluar jalur: tiga pembacaan berturut-turut, bukan satu.
    if (keadaan.jarakDariRuteM > ambangKeluarJalurM) {
      _keluarJalurBerturut++;
      if (_keluarJalurBerturut >= 3 && !state.menghitungUlang) {
        unawaited(_hitungUlang(lat, lng));
      }
      return;
    }
    _keluarJalurBerturut = 0;

    if (keadaan.indeksLangkah != _indeksTerakhir) {
      _indeksTerakhir = keadaan.indeksLangkah;
      _sudahDiumumkan.clear();
    }

    final langkah = state.langkah;
    if (langkah == null) return;

    final ambang = ambangBaru(
      keadaan.jarakKeManuverM,
      _sudahDiumumkan,
      jarakLangkah: langkah.jarakM,
    );
    if (ambang == null) return;

    _sudahDiumumkan.add(ambang);
    unawaited(_ucap(kalimatNavigasi(langkah, keadaan.jarakKeManuverM)));
  }

  Future<void> _hitungUlang(double lat, double lng) async {
    final rute = state.rute;
    if (rute == null) return;

    state = state.copyWith(menghitungUlang: true);
    await _ucap('Kamu keluar dari rute. Tourvella menghitung ulang.');
    try {
      final baru = await ref
          .read(navigasiRepositoryProvider)
          .hitung(dariLat: lat, dariLng: lng, ke: rute.tujuan);
      _penjejak = PenjejakRute(baru);
      _sudahDiumumkan.clear();
      _indeksTerakhir = -1;
      _keluarJalurBerturut = 0;
      state = state.copyWith(rute: baru, menghitungUlang: false);
    } catch (_) {
      // Sinyal hilang di tengah jalan: rute lama tetap dipakai, dan
      // dicoba lagi pada pembacaan berikutnya.
      _keluarJalurBerturut = 0;
      state = state.copyWith(
        menghitungUlang: false,
        pesan: 'Belum bisa menghitung ulang rute. Tourvella coba lagi nanti.',
      );
    }
  }

  Future<void> aturBisu(bool bisu) async {
    state = state.copyWith(bisu: bisu);
    if (bisu) await _tts.stop();
  }

  /// Ulangi petunjuk terakhir — tombol yang paling dicari saat lewat
  /// persimpangan ramai.
  Future<void> ulangi() async {
    final langkah = state.langkah;
    final keadaan = state.keadaan;
    if (langkah == null || keadaan == null) return;
    await _ucap(kalimatNavigasi(langkah, keadaan.jarakKeManuverM));
  }

  Future<void> berhenti({bool diam = false}) async {
    await _posisi?.cancel();
    _posisi = null;
    _penjejak = null;
    if (!diam) await _tts.stop();
    state = NavigasiState(bisu: state.bisu);
  }
}

final navigasiControllerProvider =
    NotifierProvider<NavigasiController, NavigasiState>(
      NavigasiController.new,
    );
