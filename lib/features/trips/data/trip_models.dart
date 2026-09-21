import 'package:flutter/foundation.dart';

/// Seberapa terbuka sebuah perjalanan.
enum TripVisibility {
  /// Hanya kamu. Ini keadaan awal setiap perjalanan di Napak.
  private('private', 'Hanya kamu'),

  /// Siapa pun yang punya tautannya.
  link('link', 'Yang punya tautan'),

  /// Terbuka untuk semua.
  public('public', 'Terbuka untuk semua');

  const TripVisibility(this.wire, this.label);

  final String wire;
  final String label;

  static TripVisibility fromWire(String value) =>
      TripVisibility.values.firstWhere(
        (v) => v.wire == value,
        orElse: () => TripVisibility.private,
      );
}

enum TripMode {
  solo('solo', 'Sendiri'),
  group('group', 'Bareng');

  const TripMode(this.wire, this.label);

  final String wire;
  final String label;

  static TripMode fromWire(String value) => TripMode.values.firstWhere(
    (v) => v.wire == value,
    orElse: () => TripMode.solo,
  );
}

enum TransportMode {
  jalanKaki('jalan_kaki', 'Jalan kaki'),
  motor('motor', 'Motor'),
  mobil('mobil', 'Mobil'),
  kereta('kereta', 'Kereta'),
  kapal('kapal', 'Kapal'),
  pesawat('pesawat', 'Pesawat'),
  tidakDiketahui('tidak_diketahui', 'Belum jelas');

  const TransportMode(this.wire, this.label);

  final String wire;
  final String label;

  static TransportMode fromWire(String value) =>
      TransportMode.values.firstWhere(
        (v) => v.wire == value,
        orElse: () => TransportMode.tidakDiketahui,
      );
}

@immutable
class Trip {
  const Trip({
    required this.id,
    required this.title,
    required this.visibility,
    required this.mode,
    required this.distanceKm,
    required this.pointCount,
    required this.isOwner,
    this.previewPath = const [],
    this.retraceOf,
    this.coverUrl,
    this.startedAt,
    this.endedAt,
    this.shareSlug,
  });

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
    id: json['id'] as String,
    title: json['title'] as String,
    visibility: TripVisibility.fromWire(json['visibility'] as String),
    mode: TripMode.fromWire(json['mode'] as String),
    distanceKm: (json['distanceKm'] as num).toDouble(),
    pointCount: json['pointCount'] as int? ?? 0,
    isOwner: json['isOwner'] as bool? ?? true,
    previewPath: [
      for (final t in (json['previewPath'] as List<dynamic>? ?? const []))
        (
          lng: ((t as List<dynamic>)[0] as num).toDouble(),
          lat: (t[1] as num).toDouble(),
        ),
    ],
    coverUrl: json['coverUrl'] as String?,
    retraceOf: json['retraceOf'] == null
        ? null
        : RingkasTrip.fromJson(json['retraceOf'] as Map<String, dynamic>),
    startedAt: _parseDate(json['startedAt']),
    endedAt: _parseDate(json['endedAt']),
    shareSlug: json['shareUrlSlug'] as String?,
  );

  final String id;
  final String title;
  final TripVisibility visibility;
  final TripMode mode;
  final double distanceKm;
  final int pointCount;
  final bool isOwner;

  /// Bentuk rute yang sudah disederhanakan, untuk pratinjau di kartu.
  ///
  /// Kosong kalau perjalanannya belum punya jejak — atau kalau backend-nya
  /// versi lama yang belum mengirim ini. Dua-duanya ditangani sama: kartunya
  /// tampil tanpa gambar, bukan rusak.
  final List<({double lat, double lng})> previewPath;

  /// Foto pertama perjalanan ini, sebagai tautan bertanda tangan.
  ///
  /// Umurnya pendek — tautan yang sama tidak bisa dipakai lagi besok. Itu
  /// disengaja: foto singgahan sama pribadinya dengan jejaknya sendiri.
  ///
  /// `null` kalau perjalanannya memang tanpa foto, dan kartunya jatuh ke
  /// pratinjau bentuk rute seperti sebelumnya.
  final String? coverUrl;

  /// Perjalanan lama yang sedang ditapak-tilasi perjalanan ini.
  final RingkasTrip? retraceOf;

  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? shareSlug;

  bool get isRecording => endedAt == null;
}

/// Rujukan ringkas ke perjalanan lain.
@immutable
class RingkasTrip {
  const RingkasTrip({required this.id, required this.title, this.startedAt});

  factory RingkasTrip.fromJson(Map<String, dynamic> json) => RingkasTrip(
    id: json['id'] as String,
    title: json['title'] as String,
    startedAt: _parseDate(json['startedAt']),
  );

  final String id;
  final String title;
  final DateTime? startedAt;
}

@immutable
class TripPoint {
  const TripPoint({
    required this.id,
    required this.lat,
    required this.lng,
    required this.recordedAt,
    required this.transportMode,
    required this.coarse,
    required this.recordedBy,
    this.speedMps,
    this.note,
    this.photoUrl,
  });

  factory TripPoint.fromJson(Map<String, dynamic> json) => TripPoint(
    id: json['id'] as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    recordedAt: DateTime.parse(json['recordedAt'] as String).toLocal(),
    transportMode: TransportMode.fromWire(json['transportMode'] as String),
    coarse: json['coarse'] as bool? ?? false,
    recordedBy: json['recordedBy'] as String? ?? '',
    speedMps: (json['speedMps'] as num?)?.toDouble(),
    note: json['note'] as String?,
    photoUrl: json['photoUrl'] as String?,
  );

  final String id;
  final double lat;
  final double lng;
  final DateTime recordedAt;
  final TransportMode transportMode;

  /// true kalau koordinat ini sengaja dikasarkan karena kamu menontonnya
  /// sebagai orang luar, bukan pemiliknya.
  final bool coarse;

  /// Siapa yang merekam titik ini. Dipakai memecah jejak jadi garis berwarna
  /// per orang di peta Trip Bareng.
  final String recordedBy;

  final double? speedMps;
  final String? note;
  final String? photoUrl;
}

@immutable
class TripMember {
  const TripMember({
    required this.userId,
    required this.name,
    required this.role,
    required this.routeColor,
    required this.liveLocationEnabled,
    required this.distanceKm,
    required this.pointCount,
  });

  factory TripMember.fromJson(Map<String, dynamic> json) => TripMember(
    userId: json['userId'] as String,
    name: json['name'] as String,
    role: json['role'] as String,
    routeColor: json['routeColor'] as String,
    liveLocationEnabled: json['liveLocationEnabled'] as bool? ?? false,
    distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
    pointCount: json['pointCount'] as int? ?? 0,
  );

  final String userId;
  final String name;
  final String role;

  /// Hex dari palet rute Napak, dikirim backend supaya warna tiap orang
  /// konsisten di semua perangkat yang menonton peta bersama.
  final String routeColor;

  final bool liveLocationEnabled;

  /// Jarak yang ditempuh anggota ini sendiri — bukan jarak gabungan
  /// seluruh rombongan.
  final double distanceKm;

  final int pointCount;

  bool get isLeader => role == 'leader';
}

@immutable
class Recap {
  const Recap({
    required this.year,
    required this.totalDistanceKm,
    required this.totalTrips,
    required this.totalCities,
    required this.cities,
    required this.caption,
    this.longestTripTitle,
    this.longestTripKm,
  });

  factory Recap.fromJson(Map<String, dynamic> json) {
    final longest = json['longestTrip'] as Map<String, dynamic>?;
    return Recap(
      year: json['year'] as int,
      totalDistanceKm: (json['totalDistanceKm'] as num).toDouble(),
      totalTrips: json['totalTrips'] as int,
      totalCities: json['totalCities'] as int,
      cities: ((json['cities'] as List<dynamic>?) ?? const [])
          .map((c) => c as String)
          .toList(),
      caption: json['caption'] as String,
      longestTripTitle: longest?['title'] as String?,
      longestTripKm: (longest?['distanceKm'] as num?)?.toDouble(),
    );
  }

  final int year;
  final double totalDistanceKm;
  final int totalTrips;
  final int totalCities;

  /// Nama kotanya, bukan cuma jumlahnya — inilah yang bikin recap terasa
  /// seperti cerita, bukan laporan.
  final List<String> cities;

  final String caption;
  final String? longestTripTitle;
  final double? longestTripKm;
}

DateTime? _parseDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();

/// Status permintaan render video animasi rute.
enum StatusRender {
  menunggu('menunggu', 'Menunggu giliran'),
  menggambar('menggambar', 'Sedang digambar'),
  selesai('selesai', 'Siap'),
  gagal('gagal', 'Gagal');

  const StatusRender(this.wire, this.label);

  final String wire;
  final String label;

  static StatusRender fromWire(String value) => StatusRender.values.firstWhere(
    (v) => v.wire == value,
    orElse: () => StatusRender.menunggu,
  );
}

enum FormatRender {
  tegak('tegak', '9:16', 'Story & Reels'),
  lebar('lebar', '16:9', 'Layar lebar');

  const FormatRender(this.wire, this.rasio, this.keterangan);

  final String wire;
  final String rasio;
  final String keterangan;
}

enum TemplateRender {
  perjalanan('perjalanan', 'Perjalanan'),
  mudik('mudik', 'Mudik');

  const TemplateRender(this.wire, this.label);

  final String wire;
  final String label;
}

@immutable
class RenderJob {
  const RenderJob({
    required this.id,
    required this.status,
    required this.format,
    required this.template,
    required this.progress,
    required this.siapDiunduh,
    this.ukuranByte,
    this.pesanGalat,
  });

  factory RenderJob.fromJson(Map<String, dynamic> json) => RenderJob(
    id: json['id'] as String,
    status: StatusRender.fromWire(json['status'] as String),
    format: json['format'] as String,
    template: json['template'] as String,
    progress: json['progress'] as int? ?? 0,
    siapDiunduh: json['siapDiunduh'] as bool? ?? false,
    ukuranByte: json['ukuranByte'] as int?,
    pesanGalat: json['pesanGalat'] as String?,
  );

  final String id;
  final StatusRender status;
  final String format;
  final String template;
  final int progress;
  final bool siapDiunduh;
  final int? ukuranByte;
  final String? pesanGalat;

  bool get sedangBerjalan =>
      status == StatusRender.menunggu || status == StatusRender.menggambar;
}

/// Posisi teman seperjalanan yang datang lewat WebSocket.
///
/// Tidak pernah disimpan — hanya dipakai menggambar penanda di peta selama
/// aplikasinya terbuka, lalu hilang.
@immutable
/// Satu orang dalam barisan konvoi.
class BarisKonvoi {
  const BarisKonvoi({
    required this.userId,
    required this.nama,
    required this.urutan,
    required this.selisihM,
    required this.tertinggal,
    required this.hilangKontak,
  });

  factory BarisKonvoi.fromJson(Map<String, dynamic> json) => BarisKonvoi(
    userId: json['userId'] as String,
    nama: json['nama'] as String,
    urutan: json['urutan'] as int,
    selisihM: (json['selisihM'] as num).toDouble(),
    tertinggal: json['tertinggal'] as bool? ?? false,
    hilangKontak: json['hilangKontak'] as bool? ?? false,
  );

  final String userId;
  final String nama;

  /// 1 = paling depan.
  final int urutan;

  /// Jarak ke yang paling depan, diukur sepanjang jalan yang ditempuh.
  final double selisihM;
  final bool tertinggal;
  final bool hilangKontak;
}

/// Susunan rombongan saat ini, dikirim server hanya saat ada yang berarti
/// berubah — bukan tiap posisi masuk.
class KabarKonvoi {
  const KabarKonvoi({
    required this.barisan,
    required this.rentangM,
    required this.pengumuman,
  });

  factory KabarKonvoi.fromJson(Map<String, dynamic> json) => KabarKonvoi(
    barisan: [
      for (final b in json['barisan'] as List<dynamic>)
        BarisKonvoi.fromJson(b as Map<String, dynamic>),
    ],
    rentangM: (json['rentangM'] as num?)?.toDouble() ?? 0,
    pengumuman: [
      for (final p in (json['pengumuman'] as List<dynamic>? ?? const []))
        (p as Map<String, dynamic>)['pesan'] as String,
    ],
  );

  final List<BarisKonvoi> barisan;
  final double rentangM;

  /// Kalimat siap tampil untuk yang baru saja mulai tertinggal.
  final List<String> pengumuman;
}

class PosisiLangsung {
  const PosisiLangsung({
    required this.userId,
    required this.nama,
    required this.lat,
    required this.lng,
    required this.pada,
  });

  factory PosisiLangsung.fromJson(Map<String, dynamic> json) => PosisiLangsung(
    userId: json['userId'] as String,
    nama: json['name'] as String? ?? 'Penjejak',
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    pada: DateTime.parse(json['at'] as String).toLocal(),
  );

  final String userId;
  final String nama;
  final double lat;
  final double lng;
  final DateTime pada;
}

/// Sinyal satu ketuk saat Trip Bareng.
///
/// Daftarnya tetap dan pendek, sama persis dengan yang dikenali server.
/// Begitu bisa menulis pesan bebas, ini berubah jadi chat — lengkap dengan
/// seluruh kewajiban yang mengikutinya.
/// Ikonnya sengaja tidak ada di sini. Model data tidak perlu tahu apa-apa
/// soal Material — pemetaan ke ikon ada di sisi tampilan.
enum Sinyal {
  isiBensin('isi_bensin', 'Isi bensin'),
  nunggu('nunggu', 'Nunggu di depan'),
  jalanDuluan('jalan_duluan', 'Jalan duluan'),
  istirahat('istirahat', 'Istirahat'),
  adaMasalah('ada_masalah', 'Ada masalah'),
  sampai('sampai', 'Sudah sampai');

  const Sinyal(this.wire, this.label);

  final String wire;
  final String label;

  static Sinyal? fromWire(String value) {
    for (final s in Sinyal.values) {
      if (s.wire == value) return s;
    }
    return null;
  }
}

/// Sinyal yang masuk dari teman seperjalanan.
@immutable
class SinyalMasuk {
  const SinyalMasuk({
    required this.userId,
    required this.nama,
    required this.sinyal,
    required this.pesan,
    required this.pada,
  });

  static SinyalMasuk? fromJson(Map<String, dynamic> json) {
    final sinyal = Sinyal.fromWire(json['kode'] as String? ?? '');
    if (sinyal == null) return null;

    return SinyalMasuk(
      userId: json['userId'] as String,
      nama: json['nama'] as String? ?? 'Penjejak',
      sinyal: sinyal,
      pesan: json['pesan'] as String? ?? sinyal.label,
      pada: DateTime.parse(json['pada'] as String).toLocal(),
    );
  }

  final String userId;
  final String nama;
  final Sinyal sinyal;
  final String pesan;
  final DateTime pada;
}
