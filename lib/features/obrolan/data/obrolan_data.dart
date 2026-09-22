import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';

DateTime _tanggal(Object? nilai) =>
    (nilai is String ? DateTime.tryParse(nilai)?.toLocal() : null) ??
    DateTime.now();

class Pesan {
  const Pesan({
    required this.id,
    required this.percakapanId,
    required this.pengirimId,
    required this.namaPengirim,
    required this.isi,
    required this.dibuat,
    this.sedangDikirim = false,
    this.gagal = false,
  });

  factory Pesan.fromJson(Map<String, dynamic> json) {
    final pengirim = json['pengirim'] as Map<String, dynamic>;
    return Pesan(
      id: json['id'] as String,
      percakapanId: json['percakapanId'] as String,
      pengirimId: pengirim['id'] as String?,
      namaPengirim: pengirim['nama'] as String,
      isi: json['isi'] as String,
      dibuat: _tanggal(json['createdAt']),
    );
  }

  final String id;
  final String percakapanId;

  /// null kalau pengirimnya sudah menghapus akunnya.
  final String? pengirimId;
  final String namaPengirim;
  final String isi;
  final DateTime dibuat;

  /// Masih menunggu balasan server. Ditampilkan redup, bukan disembunyikan —
  /// pesan yang hilang begitu diketuk kirim terasa seperti tidak terkirim.
  final bool sedangDikirim;
  final bool gagal;
}

class Percakapan {
  const Percakapan({
    required this.id,
    required this.jenis,
    required this.judul,
    required this.peserta,
    required this.belumDibaca,
    this.tripId,
    this.pesanTerakhir,
    this.waktuTerakhir,
    this.terakhirOlehSaya = false,
  });

  factory Percakapan.fromJson(Map<String, dynamic> json) {
    final terakhir = json['pesanTerakhir'] as Map<String, dynamic>?;
    return Percakapan(
      id: json['id'] as String,
      jenis: json['jenis'] as String,
      judul: json['judul'] as String,
      tripId: json['tripId'] as String?,
      peserta: [
        for (final p in json['peserta'] as List<dynamic>)
          (p as Map<String, dynamic>)['nama'] as String,
      ],
      pesanTerakhir: terakhir?['isi'] as String?,
      waktuTerakhir: terakhir == null ? null : _tanggal(terakhir['pada']),
      terakhirOlehSaya: terakhir?['olehSaya'] as bool? ?? false,
      belumDibaca: json['belumDibaca'] as int? ?? 0,
    );
  }

  final String id;

  /// `langsung` atau `perjalanan`.
  final String jenis;
  final String judul;
  final String? tripId;
  final List<String> peserta;
  final String? pesanTerakhir;
  final DateTime? waktuTerakhir;
  final bool terakhirOlehSaya;
  final int belumDibaca;

  bool get rombongan => jenis == 'perjalanan';
}

class ObrolanRepository {
  ObrolanRepository(this._api);

  final ApiClient _api;

  Future<List<Percakapan>> daftar() async {
    final data = await _api.get<List<dynamic>>('/obrolan');
    return [
      for (final p in data) Percakapan.fromJson(p as Map<String, dynamic>),
    ];
  }

  Future<String> mulaiDengan(String temanId) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/obrolan/langsung',
      body: {'temanId': temanId},
    );
    return data['id'] as String;
  }

  Future<String> ruangPerjalanan(String tripId) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/obrolan/perjalanan/$tripId',
    );
    return data['id'] as String;
  }

  /// Terbaru dulu, sama seperti yang dikirim server.
  Future<List<Pesan>> riwayat(String percakapanId, {DateTime? sebelum}) async {
    final data = await _api.get<List<dynamic>>(
      '/obrolan/$percakapanId/pesan',
      query: {
        if (sebelum != null) 'sebelum': sebelum.toUtc().toIso8601String(),
      },
    );
    return [for (final p in data) Pesan.fromJson(p as Map<String, dynamic>)];
  }

  /// Jalur cadangan saat socket-nya putus.
  Future<Pesan> kirim(String percakapanId, String isi) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/obrolan/$percakapanId/pesan',
      body: {'isi': isi},
    );
    return Pesan.fromJson(data);
  }

  Future<void> tandaiDibaca(String percakapanId) =>
      _api.post<dynamic>('/obrolan/$percakapanId/dibaca');
}

/// Sambungan waktu nyata ke satu ruang obrolan.
///
/// Dibuka saat layar obrolan dibuka, ditutup saat ditinggalkan — sama seperti
/// posisi langsung. Socket yang menganggur sepanjang aplikasi hidup berarti
/// radio HP menyala tanpa alasan.
class ObrolanSocket {
  ObrolanSocket({required String alamatDasar, required this.ambilToken})
    : _alamat = Uri.parse(alamatDasar).replace(path: '/obrolan').toString();

  final String _alamat;
  final Future<String?> Function() ambilToken;

  io.Socket? _socket;
  String? _ruang;

  final _pesan = StreamController<Pesan>.broadcast();
  final _mengetik =
      StreamController<({String userId, String nama})>.broadcast();
  final _tersambung = StreamController<bool>.broadcast();
  final _galat = StreamController<String>.broadcast();

  Stream<Pesan> get pesan => _pesan.stream;
  Stream<({String userId, String nama})> get mengetik => _mengetik.stream;
  Stream<bool> get tersambung => _tersambung.stream;
  Stream<String> get galat => _galat.stream;

  bool get aktif => _socket?.connected ?? false;

  Future<void> masuk(String percakapanId) async {
    final token = await ambilToken();
    if (token == null) return;
    if (_socket != null && _ruang == percakapanId) return;
    await keluar();

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
      socket.emit('obrolan:masuk', {'percakapanId': percakapanId});
    });

    socket.on('pesan:masuk', (data) {
      if (data is! Map) return;
      try {
        _pesan.add(Pesan.fromJson(Map<String, dynamic>.from(data)));
      } catch (error) {
        debugPrint('Pesan tidak terbaca: $error');
      }
    });

    socket.on('pesan:mengetik', (data) {
      if (data is! Map) return;
      _mengetik.add((
        userId: data['userId'] as String? ?? '',
        nama: data['nama'] as String? ?? '',
      ));
    });

    socket.on('tourvella:error', (data) {
      if (data is Map && data['message'] is String) {
        _galat.add(data['message'] as String);
      }
    });

    socket.onDisconnect((_) => _tersambung.add(false));
    socket.onConnectError((_) => _tersambung.add(false));

    socket.connect();
    _socket = socket;
    _ruang = percakapanId;
  }

  void kirim(String isi) {
    final ruang = _ruang;
    if (ruang == null) return;
    _socket?.emit('pesan:kirim', {'percakapanId': ruang, 'isi': isi});
  }

  void sedangMengetik() {
    final ruang = _ruang;
    if (ruang == null) return;
    _socket?.emit('pesan:mengetik', {'percakapanId': ruang});
  }

  Future<void> keluar() async {
    final socket = _socket;
    if (socket == null) return;
    if (_ruang != null) {
      socket.emit('obrolan:keluar', {'percakapanId': _ruang});
    }
    socket.dispose();
    _socket = null;
    _ruang = null;
  }

  Future<void> tutup() async {
    await keluar();
    await _pesan.close();
    await _mengetik.close();
    await _tersambung.close();
    await _galat.close();
  }
}

final obrolanRepositoryProvider = Provider<ObrolanRepository>(
  (ref) => ObrolanRepository(ref.watch(apiClientProvider)),
);

final daftarObrolanProvider = FutureProvider.autoDispose<List<Percakapan>>(
  (ref) => ref.watch(obrolanRepositoryProvider).daftar(),
);

/// Siapa aku, untuk membedakan gelembung sendiri dari milik orang lain.
///
/// Dibaca dari access token yang sudah tersimpan — tidak perlu satu
/// permintaan lagi ke server hanya untuk tahu id sendiri.
final idSayaProvider = FutureProvider<String?>((ref) async {
  final token = await ref.watch(tokenStoreProvider).readAccessToken();
  return idDariToken(token);
});

/// Mengambil `sub` dari JWT tanpa memverifikasinya.
///
/// Aman untuk dipakai begini karena hasilnya hanya untuk tampilan: token yang
/// dipalsukan cuma membuat gelembung pesannya salah sisi di HP pemalsunya
/// sendiri. Server tetap memeriksa tandatangannya di setiap permintaan.
String? idDariToken(String? token) {
  if (token == null) return null;
  final bagian = token.split('.');
  if (bagian.length != 3) return null;
  try {
    final muatan = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(bagian[1]))),
    );
    return muatan is Map ? muatan['sub'] as String? : null;
  } catch (_) {
    return null;
  }
}
