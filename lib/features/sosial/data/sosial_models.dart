DateTime? _tanggal(Object? nilai) =>
    nilai is String ? DateTime.tryParse(nilai)?.toLocal() : null;

class Teman {
  const Teman({
    required this.id,
    required this.nama,
    required this.kode,
    this.sejak,
    this.fotoUrl,
  });

  factory Teman.fromJson(Map<String, dynamic> json) => Teman(
    id: json['id'] as String,
    nama: json['name'] as String,
    kode: json['friendCode'] as String,
    sejak: _tanggal(json['sejak']),
    fotoUrl: json['fotoUrl'] as String?,
  );

  final String id;
  final String nama;
  final String kode;
  final DateTime? sejak;
  final String? fotoUrl;

  /// Huruf depan, untuk yang belum memasang foto profil.
  String get inisial {
    final bagian = nama.trim().split(RegExp(r'\s+'));
    if (bagian.isEmpty || bagian.first.isEmpty) return '?';
    if (bagian.length == 1) return bagian.first[0].toUpperCase();
    return (bagian.first[0] + bagian.last[0]).toUpperCase();
  }
}

class PermintaanTeman {
  const PermintaanTeman({
    required this.id,
    required this.orang,
    required this.dibuat,
  });

  factory PermintaanTeman.dariMasuk(Map<String, dynamic> json) =>
      PermintaanTeman(
        id: json['id'] as String,
        orang: Teman.fromJson(json['dari'] as Map<String, dynamic>),
        dibuat: _tanggal(json['createdAt']) ?? DateTime.now(),
      );

  factory PermintaanTeman.dariTerkirim(Map<String, dynamic> json) =>
      PermintaanTeman(
        id: json['id'] as String,
        orang: Teman.fromJson(json['ke'] as Map<String, dynamic>),
        dibuat: _tanggal(json['createdAt']) ?? DateTime.now(),
      );

  final String id;
  final Teman orang;
  final DateTime dibuat;
}

/// Hasil mencari seseorang lewat kode Napak-nya.
class HasilCari {
  const HasilCari({
    required this.id,
    required this.nama,
    required this.kode,
    required this.status,
  });

  factory HasilCari.fromJson(Map<String, dynamic> json) => HasilCari(
    id: json['id'] as String,
    nama: json['name'] as String,
    kode: json['friendCode'] as String,
    status: json['status'] as String,
  );

  final String id;
  final String nama;
  final String kode;

  /// `diri_sendiri` | `belum` | `menunggu` | `diterima`
  final String status;
}

enum JenisKabar {
  permintaanTeman('permintaan_teman'),
  temanDiterima('teman_diterima'),
  undanganTrip('undangan_trip'),
  undanganDijawab('undangan_dijawab'),
  videoSiap('video_siap'),
  kartuPos('kartu_pos'),
  pesanBaru('pesan_baru'),
  kenangan('kenangan'),
  lain('lain');

  const JenisKabar(this.wire);
  final String wire;

  static JenisKabar dari(String wire) => JenisKabar.values.firstWhere(
    (j) => j.wire == wire,
    // Jenis baru dari server yang belum dikenal versi aplikasi ini tetap
    // tampil sebagai kabar biasa, bukan membuat seluruh inbox gagal dibaca.
    orElse: () => JenisKabar.lain,
  );
}

class Kabar {
  const Kabar({
    required this.id,
    required this.jenis,
    required this.judul,
    required this.isi,
    required this.sudahDibaca,
    required this.dibuat,
    this.tautan,
    this.data = const {},
  });

  factory Kabar.fromJson(Map<String, dynamic> json) => Kabar(
    id: json['id'] as String,
    jenis: JenisKabar.dari(json['jenis'] as String),
    judul: json['judul'] as String,
    isi: json['isi'] as String,
    tautan: json['tautan'] as String?,
    data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    sudahDibaca: json['sudahDibaca'] as bool? ?? false,
    dibuat: _tanggal(json['createdAt']) ?? DateTime.now(),
  );

  final String id;
  final JenisKabar jenis;
  final String judul;
  final String isi;
  final String? tautan;
  final Map<String, dynamic> data;
  final bool sudahDibaca;
  final DateTime dibuat;

  Kabar dibaca() => Kabar(
    id: id,
    jenis: jenis,
    judul: judul,
    isi: isi,
    tautan: tautan,
    data: data,
    sudahDibaca: true,
    dibuat: dibuat,
  );
}

class UndanganTrip {
  const UndanganTrip({
    required this.id,
    required this.tripId,
    required this.judulTrip,
    required this.dari,
    this.berangkat,
  });

  factory UndanganTrip.fromJson(Map<String, dynamic> json) {
    final trip = json['trip'] as Map<String, dynamic>;
    final dari = json['dari'] as Map<String, dynamic>;
    return UndanganTrip(
      id: json['id'] as String,
      tripId: trip['id'] as String,
      judulTrip: trip['title'] as String,
      berangkat: _tanggal(trip['startedAt']),
      dari: dari['name'] as String,
    );
  }

  final String id;
  final String tripId;
  final String judulTrip;
  final String dari;
  final DateTime? berangkat;
}

class KartuPos {
  const KartuPos({
    required this.id,
    required this.dari,
    required this.untukSaya,
    required this.fotoUrl,
    required this.sudahDibaca,
    required this.dibuat,
    this.pesan,
    this.tempat,
    this.tripId,
  });

  factory KartuPos.fromJson(Map<String, dynamic> json) => KartuPos(
    id: json['id'] as String,
    dari: (json['dari'] as Map<String, dynamic>)['nama'] as String,
    untukSaya: json['untukSaya'] as bool? ?? true,
    fotoUrl: json['fotoUrl'] as String,
    pesan: json['pesan'] as String?,
    tempat: json['tempat'] as String?,
    tripId: json['tripId'] as String?,
    sudahDibaca: json['sudahDibaca'] as bool? ?? false,
    dibuat: _tanggal(json['createdAt']) ?? DateTime.now(),
  );

  final String id;
  final String dari;
  final bool untukSaya;
  final String fotoUrl;
  final String? pesan;
  final String? tempat;
  final String? tripId;
  final bool sudahDibaca;
  final DateTime dibuat;
}

class ProvinsiTerjejak {
  const ProvinsiTerjejak({
    required this.nama,
    required this.kota,
    required this.totalKota,
    this.pertama,
  });

  factory ProvinsiTerjejak.fromJson(Map<String, dynamic> json) =>
      ProvinsiTerjejak(
        nama: json['provinsi'] as String,
        kota: (json['kota'] as List<dynamic>).cast<String>(),
        totalKota: json['totalKota'] as int? ?? 0,
        pertama: _tanggal(json['pertama']),
      );

  final String nama;
  final List<String> kota;
  final int totalKota;
  final DateTime? pertama;

  double get porsi => totalKota == 0 ? 0 : kota.length / totalKota;
}

class TitikKota {
  const TitikKota({
    required this.nama,
    required this.provinsi,
    required this.lat,
    required this.lng,
    required this.sudah,
  });

  factory TitikKota.fromJson(Map<String, dynamic> json) => TitikKota(
    nama: json['nama'] as String,
    provinsi: json['provinsi'] as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    sudah: json['sudah'] as bool? ?? false,
  );

  final String nama;
  final String provinsi;
  final double lat;
  final double lng;
  final bool sudah;
}

class JejakNusantara {
  const JejakNusantara({
    required this.provinsiTerjejak,
    required this.totalProvinsi,
    required this.kotaTerjejak,
    required this.totalKota,
    required this.sudah,
    required this.belum,
    required this.titik,
  });

  factory JejakNusantara.fromJson(Map<String, dynamic> json) => JejakNusantara(
    provinsiTerjejak: json['provinsiTerjejak'] as int,
    totalProvinsi: json['totalProvinsi'] as int,
    kotaTerjejak: json['kotaTerjejak'] as int,
    totalKota: json['totalKota'] as int,
    sudah: [
      for (final p in json['sudah'] as List<dynamic>)
        ProvinsiTerjejak.fromJson(p as Map<String, dynamic>),
    ],
    belum: (json['belum'] as List<dynamic>).cast<String>(),
    titik: [
      for (final t in (json['titik'] as List<dynamic>? ?? const []))
        TitikKota.fromJson(t as Map<String, dynamic>),
    ],
  );

  final int provinsiTerjejak;
  final int totalProvinsi;
  final int kotaTerjejak;
  final int totalKota;
  final List<ProvinsiTerjejak> sudah;
  final List<String> belum;
  final List<TitikKota> titik;
}
