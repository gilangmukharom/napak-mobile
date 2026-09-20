import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../trips/data/trip_models.dart';

/// Sambungan posisi langsung saat Trip Bareng.
///
/// Yang lewat di sini tidak pernah menyentuh database — server hanya
/// meneruskannya ke anggota lain yang sedang menonton, lalu posisinya hilang.
/// Jejak yang permanen tetap masuk lewat jalur biasa dan terenkripsi.
///
/// Sambungan baru dibuka saat ada layar yang benar-benar menonton, dan ditutup
/// begitu layarnya ditinggalkan. Membiarkan socket terbuka sepanjang aplikasi
/// hidup berarti radio HP menyala tanpa alasan.
class LiveLocationService {
  LiveLocationService({
    required String alamatDasar,
    required this.ambilToken,
  }) : _alamatSocket = _keAlamatSocket(alamatDasar);

  final String _alamatSocket;

  /// Pengambil access token, disuntik supaya socket tidak perlu tahu
  /// di mana token disimpan.
  final Future<String?> Function() ambilToken;

  io.Socket? _socket;
  String? _tripYangDitonton;

  final _posisi = StreamController<PosisiLangsung>.broadcast();
  final _galat = StreamController<String>.broadcast();
  final _tersambung = StreamController<bool>.broadcast();

  /// Posisi teman seperjalanan yang masuk satu per satu.
  Stream<PosisiLangsung> get posisi => _posisi.stream;

  /// Pesan yang layak ditampilkan ke pengguna, sudah Bahasa Indonesia dari server.
  Stream<String> get galat => _galat.stream;

  Stream<bool> get tersambung => _tersambung.stream;

  /// Buka sambungan dan mulai menonton peta bersama satu perjalanan.
  Future<void> tonton(String tripId) async {
    final token = await ambilToken();
    if (token == null) return;

    if (_socket != null && _tripYangDitonton == tripId) return;
    await putus();

    final socket = io.io(
      _alamatSocket,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      _tersambung.add(true);
      socket.emit('trip:watch', {'tripId': tripId});
    });

    socket.on('position:update', (data) {
      if (data is! Map) return;
      try {
        _posisi.add(PosisiLangsung.fromJson(Map<String, dynamic>.from(data)));
      } catch (error) {
        debugPrint('Posisi langsung tidak terbaca: $error');
      }
    });

    socket.on('napak:error', (data) {
      if (data is Map && data['message'] is String) {
        _galat.add(data['message'] as String);
      }
    });

    socket.onDisconnect((_) => _tersambung.add(false));
    socket.onConnectError((_) {
      _tersambung.add(false);
      _galat.add('Belum tersambung ke rombongan. Napak akan mencoba lagi.');
    });

    socket.connect();
    _socket = socket;
    _tripYangDitonton = tripId;
  }

  /// Kirim posisimu sendiri ke rombongan.
  ///
  /// Server tetap memeriksa izinnya sekali lagi sebelum meneruskan — jadi
  /// memanggil ini saat berbagi posisi sedang mati tidak akan membocorkan
  /// apa pun, hanya membalas dengan pesan.
  void bagikanPosisi({
    required String tripId,
    required double lat,
    required double lng,
    double? speedMps,
  }) {
    _socket?.emit('position:share', {
      'tripId': tripId,
      'lat': lat,
      'lng': lng,
      'at': DateTime.now().toUtc().toIso8601String(),
      'speedMps': ?speedMps,
    });
  }

  Future<void> putus() async {
    final socket = _socket;
    if (socket == null) return;

    if (_tripYangDitonton != null) {
      socket.emit('trip:unwatch', {'tripId': _tripYangDitonton});
    }
    socket.dispose();
    _socket = null;
    _tripYangDitonton = null;
    _tersambung.add(false);
  }

  Future<void> tutup() async {
    await putus();
    await _posisi.close();
    await _galat.close();
    await _tersambung.close();
  }

  /// `http://host:3000/api` → `http://host:3000/live`
  ///
  /// Namespace `/live` ada di akar server, bukan di bawah prefix `/api`.
  static String _keAlamatSocket(String alamatDasar) {
    final uri = Uri.parse(alamatDasar);
    return uri.replace(path: '/live').toString();
  }
}
