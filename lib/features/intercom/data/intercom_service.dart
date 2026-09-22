import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:record/record.dart' hide IosAudioCategory;
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'olah_suara.dart';

@immutable
class AnggotaSuara {
  const AnggotaSuara({
    required this.userId,
    required this.nama,
    required this.bisu,
  });

  factory AnggotaSuara.fromJson(Map<String, dynamic> json) => AnggotaSuara(
    userId: json['userId'] as String,
    nama: json['nama'] as String? ?? 'Penjejak',
    bisu: json['bisu'] as bool? ?? false,
  );

  final String userId;
  final String nama;
  final bool bisu;
}

/// Intercom Trip Bareng: mikrofon, speaker, dan sambungan ke ruang suara.
///
/// Suara lewat server (namespace `/intercom`), bukan dari HP ke HP — lihat
/// `intercom.gateway.ts` untuk alasannya. Server hanya meneruskan; tidak ada
/// yang direkam atau disimpan di mana pun, termasuk di HP ini.
///
/// Urutan menyalakan audio di iOS penting: pemutar disiapkan lebih dulu,
/// baru perekam. Keduanya mengatur sesi audio yang sama, dan perekam yang
/// terakhir memasang opsi speaker dan Bluetooth (helm berintercom). Dibalik,
/// pemutar menimpa opsi itu dan suara keluar dari speaker telinga yang kecil.
class IntercomService {
  IntercomService({required String alamatDasar, required this.ambilToken})
    : _alamat = Uri.parse(alamatDasar).replace(path: '/intercom').toString();

  final String _alamat;
  final Future<String?> Function() ambilToken;

  io.Socket? _socket;
  AudioRecorder? _perekam;
  StreamSubscription<Uint8List>? _mikrofon;

  final _pemotong = PemotongPcm();
  final _pendeteksi = PendeteksiSuara();
  final pencampur = PencampurSuara();

  bool _bisu = false;
  bool _sayaBicara = false;

  final _anggota = StreamController<List<AnggotaSuara>>.broadcast();
  final _galat = StreamController<String>.broadcast();
  final _tersambung = StreamController<bool>.broadcast();

  Stream<List<AnggotaSuara>> get anggota => _anggota.stream;
  Stream<String> get galat => _galat.stream;
  Stream<bool> get tersambung => _tersambung.stream;

  /// Suaramu sendiri sedang terkirim (tidak bisu dan ada yang diucapkan).
  bool get sayaBicara => _sayaBicara;

  bool get aktif => _socket != null;

  /// Minta izin mikrofon. Di iOS inilah saat teks izin di Info.plist muncul.
  Future<bool> mintaIzinMikrofon() async {
    final perekam = _perekam ??= AudioRecorder();
    return perekam.hasPermission();
  }

  Future<void> masuk(String tripId, {required bool bisu}) async {
    await keluar();
    _bisu = bisu;

    final token = await ambilToken();
    if (token == null) {
      _galat.add('Kamu perlu masuk dulu.');
      return;
    }

    // 1. Pemutar lebih dulu — lihat catatan urutan di atas.
    await FlutterPcmSound.setup(
      sampleRate: lajuSampel,
      channelCount: 1,
      iosAudioCategory: IosAudioCategory.playAndRecord,
      // Intercom tetap jalan saat layar HP dikunci di saku jaket.
      iosAllowBackgroundAudio: true,
    );
    await FlutterPcmSound.setFeedThreshold(sampelPerPotongan * 2);
    FlutterPcmSound.setFeedCallback(_isiSpeaker);
    FlutterPcmSound.start();

    // 2. Sambungan.
    final socket = io.io(
      _alamat,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      _tersambung.add(true);
      // Masuk ulang tiap tersambung lagi: sinyal hilang di terowongan tidak
      // boleh membuat orang harus mengetuk "Gabung" lagi.
      socket.emit('ruang:masuk', {'tripId': tripId, 'bisu': _bisu});
    });
    socket.onDisconnect((_) => _tersambung.add(false));
    socket.onConnectError((_) => _tersambung.add(false));

    socket.on('ruang:anggota', (data) {
      if (data is! Map || data['anggota'] is! List) return;
      _anggota.add([
        for (final a in data['anggota'] as List)
          if (a is Map) AnggotaSuara.fromJson(Map<String, dynamic>.from(a)),
      ]);
    });

    socket.on('suara:masuk', (data) {
      if (data is! Map) return;
      final dari = data['u'];
      final isi = _keByte(data['d']);
      if (dari is! String || isi == null || isi.isEmpty) return;
      pencampur.terima(dari, dariMulaw(isi));
    });

    socket.on('tourvella:error', (data) {
      if (data is Map && data['message'] is String) {
        _galat.add(data['message'] as String);
      }
    });

    socket.connect();
    _socket = socket;

    // 3. Mikrofon.
    try {
      final perekam = _perekam ??= AudioRecorder();
      final aliran = await perekam.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: lajuSampel,
          numChannels: 1,
          // Tanpa ini, suara teman yang keluar dari speaker ikut masuk
          // mikrofon dan kembali ke telinga mereka sendiri.
          echoCancel: true,
          noiseSuppress: true,
          autoGain: true,
          androidConfig: AndroidRecordConfig(
            audioSource: AndroidAudioSource.voiceCommunication,
            audioManagerMode: AudioManagerMode.modeInCommunication,
            speakerphone: true,
          ),
        ),
      );
      _mikrofon = aliran.listen(_dariMikrofon);
    } catch (error) {
      debugPrint('Mikrofon intercom gagal: $error');
      _galat.add(
        'Mikrofon tidak bisa dipakai. Kamu tetap bisa mendengar rombongan.',
      );
    }
  }

  void _dariMikrofon(Uint8List byte) {
    final socket = _socket;
    var terkirim = false;

    for (final potongan in _pemotong.masukkan(byte)) {
      // Bisu = tidak ada satu byte pun yang keluar dari HP ini. Server juga
      // membuang bingkai dari orang yang bisu, tapi yang pertama menjaga
      // adalah HP-nya sendiri.
      if (_bisu || socket == null || !socket.connected) continue;

      for (final kirim in _pendeteksi.saring(potongan)) {
        socket.emit('suara:kirim', keMulaw(kirim));
        terkirim = true;
      }
    }
    _sayaBicara = terkirim;
  }

  /// Dipanggil pemutar saat antreannya menipis: selalu diberi sesuatu,
  /// diam kalau tidak ada yang bicara, supaya pemutarnya tidak berhenti dan
  /// suara pertama berikutnya tidak tertahan.
  void _isiSpeaker(int _) {
    final campuran = pencampur.ambil();
    unawaited(
      FlutterPcmSound.feed(
        PcmArrayInt16(bytes: ByteData.sublistView(campuran)),
      ),
    );
  }

  void aturBisu(bool bisu) {
    _bisu = bisu;
    if (bisu) _sayaBicara = false;
    _socket?.emit('ruang:bisu', {'bisu': bisu});
  }

  Future<void> keluar() async {
    await _mikrofon?.cancel();
    _mikrofon = null;
    try {
      await _perekam?.stop();
    } catch (_) {}

    final socket = _socket;
    _socket = null;
    if (socket != null) {
      socket.emit('ruang:keluar');
      socket.dispose();
      _tersambung.add(false);
    }

    FlutterPcmSound.setFeedCallback(null);
    try {
      await FlutterPcmSound.release();
    } catch (_) {}

    pencampur.kosongkan();
    _sayaBicara = false;
  }

  Future<void> tutup() async {
    await keluar();
    await _perekam?.dispose();
    _perekam = null;
    await _anggota.close();
    await _galat.close();
    await _tersambung.close();
  }

  static Uint8List? _keByte(Object? data) => switch (data) {
    final Uint8List b => b,
    final ByteBuffer b => b.asUint8List(),
    final List<int> b => Uint8List.fromList(b),
    _ => null,
  };
}
