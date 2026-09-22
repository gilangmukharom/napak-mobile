import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../../../core/config/tourvella_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import 'layanan_data.dart';

typedef Kotak = ({double s, double w, double n, double e});

/// Wilayah siap unduh.
///
/// Dipilih mengikuti cara orang Indonesia bepergian, bukan batas
/// administrasi yang rapi: Jabodetabek untuk yang pulang-pergi kerja, Pantura
/// untuk yang mudik, dan jalur touring yang sinyalnya memang hilang — Bromo,
/// Dieng, pantai selatan.
class WilayahSiap {
  const WilayahSiap(this.nama, this.keterangan, this.kotak);

  final String nama;
  final String keterangan;
  final Kotak kotak;
}

const wilayahSiap = <WilayahSiap>[
  WilayahSiap(
    'Bromo – Tengger – Semeru',
    'Jalur touring, sinyal sering hilang',
    (s: -8.25, w: 112.55, n: -7.75, e: 113.10),
  ),
  WilayahSiap('Dieng – Wonosobo', 'Dataran tinggi, jalan berkelok', (
    s: -7.45,
    w: 109.75,
    n: -7.10,
    e: 110.05,
  )),
  WilayahSiap(
    'Pangalengan – Garut Selatan',
    'Kebun teh sampai pantai Santolo',
    (s: -7.75, w: 107.45, n: -7.00, e: 107.95),
  ),
  WilayahSiap('Jabodetabek', 'Jakarta, Bogor, Depok, Tangerang, Bekasi', (
    s: -6.75,
    w: 106.45,
    n: -6.05,
    e: 107.20,
  )),
  WilayahSiap('Pantura Jakarta – Cirebon', 'Jalur mudik utama', (
    s: -6.85,
    w: 106.90,
    n: -6.10,
    e: 108.65,
  )),
  WilayahSiap('Pantura Cirebon – Semarang', 'Brebes, Tegal, Pekalongan', (
    s: -7.10,
    w: 108.45,
    n: -6.75,
    e: 110.55,
  )),
  WilayahSiap(
    'Yogyakarta & sekitarnya',
    'Jogja, Magelang, Klaten, Gunungkidul',
    (s: -8.20, w: 110.00, n: -7.45, e: 110.85),
  ),
  WilayahSiap('Malang Raya', 'Malang, Batu, Singosari', (
    s: -8.15,
    w: 112.45,
    n: -7.75,
    e: 112.80,
  )),
  WilayahSiap('Bali', 'Seluruh pulau', (
    s: -8.90,
    w: 114.40,
    n: -8.05,
    e: 115.75,
  )),
  WilayahSiap('Lombok', 'Seluruh pulau', (
    s: -9.00,
    w: 115.80,
    n: -8.20,
    e: 116.75,
  )),
];

/// Seberapa rinci peta yang dibawa.
enum Kerincian {
  lengkap(14, 'Lengkap', 'Semua jalan sampai gang, nama jalan, SPBU, bangunan'),
  hemat(12, 'Hemat', 'Jalan utama dan kota saja — jauh lebih kecil');

  const Kerincian(this.zoomMaks, this.label, this.keterangan);
  final int zoomMaks;
  final String label;
  final String keterangan;
}

class PerkiraanUnduhan {
  const PerkiraanUnduhan({required this.tile, required this.byte});

  final int tile;
  final int byte;

  String get teksUkuran {
    final mb = byte / (1024 * 1024);
    if (mb < 1) return '${(byte / 1024).round()} KB';
    if (mb < 1024) return '${mb.round()} MB';
    return '${(mb / 1024).toStringAsFixed(1).replaceAll('.', ',')} GB';
  }
}

class WilayahOffline {
  const WilayahOffline({
    required this.id,
    required this.nama,
    required this.kotak,
    required this.zoomMaks,
    required this.alamatGaya,
    this.ukuranByte,
    this.jumlahLayanan,
    this.diunduh,
  });

  final int id;
  final String nama;
  final Kotak kotak;
  final int zoomMaks;
  final String alamatGaya;
  final int? ukuranByte;
  final int? jumlahLayanan;
  final DateTime? diunduh;

  /// Peta offline dikenali dari alamat gayanya. Kalau alamat server berubah
  /// — tunnel uji coba berganti alamat tiap dijalankan ulang — tile yang
  /// tersimpan tidak lagi cocok dengan yang diminta peta.
  bool get cocokDenganServer => alamatGaya == TourvellaConfig.mapStyleUrl;
}

sealed class KemajuanUnduh {
  const KemajuanUnduh();
}

class SedangMengunduh extends KemajuanUnduh {
  const SedangMengunduh(this.porsi, this.selesai, this.total);
  final double porsi;
  final int selesai;
  final int total;
}

class MengunduhLayanan extends KemajuanUnduh {
  const MengunduhLayanan();
}

class UnduhanSelesai extends KemajuanUnduh {
  const UnduhanSelesai(this.wilayah);
  final WilayahOffline wilayah;
}

class UnduhanGagal extends KemajuanUnduh {
  const UnduhanGagal(this.pesan);
  final String pesan;
}

/// Peta offline.
///
/// Yang diunduh tile vektor dari server Tourvella sendiri — bukan dari penyedia
/// peta luar — lalu disimpan MapLibre di HP. Setelah itu, peta di wilayah
/// itu tetap tergambar lengkap dengan nama jalannya walau sinyal hilang.
///
/// SPBU dan bengkel di wilayah yang sama ikut disimpan, supaya "bengkel
/// terdekat" tetap bisa dijawab di tempat yang paling membutuhkannya: jalan
/// gunung tanpa sinyal.
class PetaOfflineService {
  PetaOfflineService(this._api, this._layanan);

  final ApiClient _api;
  final LayananRepository _layanan;
  bool _batasDiatur = false;

  Future<bool> petaServerTersedia() async {
    final data = await _api.get<Map<String, dynamic>>('/map/status');
    return data['tersedia'] as bool? ?? false;
  }

  Future<PerkiraanUnduhan> perkiraan(Kotak k, Kerincian kerincian) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/map/perkiraan',
      query: {
        's': '${k.s}',
        'w': '${k.w}',
        'n': '${k.n}',
        'e': '${k.e}',
        'z': '${kerincian.zoomMaks}',
      },
    );
    return PerkiraanUnduhan(
      tile: (data['tile'] as num).toInt(),
      byte: (data['byte'] as num).toInt(),
    );
  }

  Future<List<WilayahOffline>> daftar() async {
    final semua = await ml.getListOfRegions();
    final hasil = <WilayahOffline>[];
    for (final r in semua) {
      int? byte = (r.metadata['byte'] as num?)?.toInt();
      try {
        byte = (await ml.getOfflineRegionStatus(r.id)).completedResourceSize;
      } catch (_) {
        // Status belum bisa dibaca; pakai perkiraan yang disimpan saat mulai.
      }
      final layanan = await _layanan.jumlahLokal(r.id);
      hasil.add(
        WilayahOffline(
          id: r.id,
          nama: r.metadata['nama'] as String? ?? 'Wilayah tanpa nama',
          kotak: (
            s: r.definition.bounds.southwest.latitude,
            w: r.definition.bounds.southwest.longitude,
            n: r.definition.bounds.northeast.latitude,
            e: r.definition.bounds.northeast.longitude,
          ),
          zoomMaks: r.definition.maxZoom.round(),
          alamatGaya: r.definition.mapStyleUrl,
          ukuranByte: byte,
          jumlahLayanan: layanan,
          diunduh: DateTime.tryParse(r.metadata['diunduh'] as String? ?? ''),
        ),
      );
    }
    return hasil;
  }

  /// Satu unduhan dalam satu waktu. Dua unduhan bersamaan membuat MapLibre
  /// mengelola dua paket sekaligus di penyimpanan yang sama — di iOS itu
  /// jalan yang paling mungkin berakhir dengan aplikasi tertutup sendiri.
  static bool _sedangMengunduh = false;

  /// Mengunduh satu wilayah. Kemajuannya mengalir lewat stream.
  Stream<KemajuanUnduh> unduh({
    required String nama,
    required Kotak kotak,
    required Kerincian kerincian,
    int? perkiraanByte,
  }) {
    final aliran = StreamController<KemajuanUnduh>();

    Future<void> jalan() async {
      if (!TourvellaConfig.petaMilikTourvella) {
        aliran.add(
          const UnduhanGagal(
            'Aplikasi ini dibangun dengan peta demo yang isinya cuma bentuk '
            'pulau. Bangun ulang aplikasinya dengan peta Tourvella dulu, baru '
            'unduh untuk offline.',
          ),
        );
        await aliran.close();
        return;
      }
      if (_sedangMengunduh) {
        aliran.add(
          const UnduhanGagal(
            'Masih ada wilayah lain yang sedang diunduh. Tunggu selesai dulu, ya.',
          ),
        );
        await aliran.close();
        return;
      }
      _sedangMengunduh = true;
      var kabarTerakhir = DateTime.fromMillisecondsSinceEpoch(0);

      try {
        if (!_batasDiatur) {
          // Bawaan MapLibre membatasi 6.000 tile per wilayah — sepotong
          // Jabodetabek pun tidak muat. Dinaikkan secukupnya.
          await ml.setOfflineTileCountLimit(250000);
          _batasDiatur = true;
        }

        final selesai = Completer<void>();
        final wilayah = await ml.downloadOfflineRegion(
          ml.OfflineRegionDefinition(
            bounds: ml.LatLngBounds(
              southwest: ml.LatLng(kotak.s, kotak.w),
              northeast: ml.LatLng(kotak.n, kotak.e),
            ),
            mapStyleUrl: TourvellaConfig.mapStyleUrl,
            minZoom: 4,
            maxZoom: kerincian.zoomMaks.toDouble(),
          ),
          metadata: {
            'nama': nama,
            'diunduh': DateTime.now().toIso8601String(),
            'byte': ?perkiraanByte,
          },
          onEvent: (status) {
            switch (status) {
              case ml.InProgress():
                // iOS mengirim kabar untuk setiap tile tanpa jeda. Yang
                // diteruskan ke layar cukup empat kali sedetik.
                final sekarang = DateTime.now();
                if (sekarang.difference(kabarTerakhir).inMilliseconds < 250) {
                  break;
                }
                kabarTerakhir = sekarang;
                aliran.add(
                  SedangMengunduh(
                    // Android melaporkan 0–100; dijepit supaya tetap benar
                    // kalau suatu platform melaporkan 0–1.
                    (status.progress > 1
                            ? status.progress / 100
                            : status.progress)
                        .clamp(0.0, 1.0),
                    status.completedResourceCount,
                    status.requiredResourceCount,
                  ),
                );
              case ml.Success():
                if (!selesai.isCompleted) selesai.complete();
              case ml.Error():
                if (!selesai.isCompleted) {
                  selesai.completeError(
                    TourvellaException(
                      'Unduhan terputus. Coba lagi saat sinyal lebih baik — '
                      'yang sudah terunduh tidak hilang.',
                    ),
                  );
                }
            }
          },
        );

        // `downloadOfflineRegion` kembali begitu unduhan dimulai; selesainya
        // ditandai event Success. Statusnya juga diperiksa berkala sebagai
        // cadangan, kalau event terakhir itu hilang di jalan.
        unawaited(_tungguLengkap(wilayah.id, selesai));
        await selesai.future;

        // Ukuran yang sebenarnya tersimpan di HP, bukan perkiraan.
        final status = await ml.getOfflineRegionStatus(wilayah.id);

        // SPBU & bengkel ikut disimpan. Kalau langkah ini gagal, petanya
        // sendiri sudah utuh di HP — jangan laporkan seluruh unduhan gagal.
        aliran.add(const MengunduhLayanan());
        var jumlah = 0;
        try {
          jumlah = await _layanan.simpanWilayah(wilayah.id, kotak);
        } catch (_) {}

        // Catatan: TIDAK memanggil `updateOfflineRegionMetadata`. Plugin
        // maplibre_gl 0.27 tidak mengimplementasikannya di iOS; memanggilnya
        // membuat unduhan yang sudah berhasil dilaporkan gagal. Ukuran dan
        // jumlah layanan dibaca ulang dari status & berkas lokal di `daftar()`.

        aliran.add(
          UnduhanSelesai(
            WilayahOffline(
              id: wilayah.id,
              nama: nama,
              kotak: kotak,
              zoomMaks: kerincian.zoomMaks,
              alamatGaya: TourvellaConfig.mapStyleUrl,
              ukuranByte: status.completedResourceSize,
              jumlahLayanan: jumlah,
              diunduh: DateTime.now(),
            ),
          ),
        );
      } catch (galat) {
        aliran.add(UnduhanGagal(_pesanManusia(galat)));
      } finally {
        _sedangMengunduh = false;
        await aliran.close();
      }
    }

    unawaited(jalan());
    return aliran.stream;
  }

  /// Galat plugin dijelaskan dengan bahasa orang, bukan nama kelas Java.
  static String _pesanManusia(Object galat) {
    if (galat is TourvellaException) return galat.message;
    final teks = galat.toString();
    if (teks.contains('tileCountLimitExceeded')) {
      return 'Wilayahnya terlalu besar untuk sekali unduh. Pilih kerincian Hemat.';
    }
    if (teks.contains('MissingPluginException')) {
      return 'Fitur ini belum didukung di perangkatmu. Perbarui aplikasinya.';
    }
    return 'Unduhan terputus. Coba lagi saat sinyal lebih baik — '
        'yang sudah terunduh tidak hilang.';
  }

  Future<void> _tungguLengkap(int id, Completer<void> selesai) async {
    while (!selesai.isCompleted) {
      await Future<void>.delayed(const Duration(seconds: 3));
      try {
        final status = await ml.getOfflineRegionStatus(id);
        if (status.isComplete && !selesai.isCompleted) selesai.complete();
      } catch (_) {
        // Status belum siap dibaca; dicoba lagi sebentar lagi.
      }
    }
  }

  Future<void> hapus(int id) async {
    await ml.deleteOfflineRegion(id);
    // Tile yang tidak lagi dipakai wilayah mana pun ikut dibuang, supaya
    // "hapus" benar-benar mengembalikan ruang penyimpanan HP.
    await ml.clearAmbientCache();
    await _layanan.hapusWilayah(id);
  }
}

final petaOfflineServiceProvider = Provider<PetaOfflineService>(
  (ref) => PetaOfflineService(
    ref.watch(apiClientProvider),
    ref.watch(layananRepositoryProvider),
  ),
);

final daftarWilayahOfflineProvider =
    FutureProvider.autoDispose<List<WilayahOffline>>(
      (ref) => ref.watch(petaOfflineServiceProvider).daftar(),
    );
