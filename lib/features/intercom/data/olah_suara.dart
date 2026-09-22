import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

/// Pengolahan suara intercom yang tidak butuh HP: kodek, pendeteksi suara,
/// dan pencampur. Dipisah dari plugin audio supaya bisa dites.

/// 16 kHz mono: suara orang terdengar jelas (bukan suara telepon zaman
/// dulu), dan masih ringan untuk sinyal seluler di jalur touring.
const int lajuSampel = 16000;

/// Satu potongan yang dikirim: 40 ms = 640 sampel = 640 byte μ-law.
/// 25 kiriman per detik — cukup rapat untuk obrolan, cukup jarang untuk
/// sinyal satu garis di tanjakan.
const int sampelPerPotongan = 640;

// --- μ-law (G.711) ---------------------------------------------------------
//
// Kodek telepon: 16 bit jadi 8 bit dengan skala logaritmik, jadi bisikan dan
// teriakan sama-sama terdengar. Separuh ukuran PCM mentah, tanpa pustaka
// native, dan kerugiannya nyaris tidak terdengar untuk suara orang bicara.

const int _bias = 0x84;
const int _batas = 32635;

int _mulawDariSampel(int sampel) {
  final tanda = sampel < 0 ? 0x80 : 0;
  var besar = sampel.abs();
  if (besar > _batas) besar = _batas;
  besar += _bias;

  var eksponen = 7;
  for (var topeng = 0x4000; (besar & topeng) == 0 && eksponen > 0; topeng >>= 1) {
    eksponen--;
  }
  final mantissa = (besar >> (eksponen + 3)) & 0x0F;
  return ~(tanda | (eksponen << 4) | mantissa) & 0xFF;
}

final Int16List _tabelBalik = Int16List.fromList([
  for (var u = 0; u < 256; u++)
    () {
      final x = ~u & 0xFF;
      final tanda = x & 0x80;
      final eksponen = (x >> 4) & 0x07;
      final mantissa = x & 0x0F;
      final besar = (((mantissa << 3) + _bias) << eksponen) - _bias;
      return tanda != 0 ? -besar : besar;
    }(),
]);

Uint8List keMulaw(Int16List pcm) {
  final hasil = Uint8List(pcm.length);
  for (var i = 0; i < pcm.length; i++) {
    hasil[i] = _mulawDariSampel(pcm[i]);
  }
  return hasil;
}

Int16List dariMulaw(Uint8List mulaw) {
  final hasil = Int16List(mulaw.length);
  for (var i = 0; i < mulaw.length; i++) {
    hasil[i] = _tabelBalik[mulaw[i]];
  }
  return hasil;
}

// --- Pemotong ----------------------------------------------------------------

/// Mengumpulkan aliran byte PCM dari mikrofon (potongannya tidak beraturan)
/// menjadi potongan 40 ms yang rapi.
class PemotongPcm {
  final _sisa = BytesBuilder(copy: false);

  Iterable<Int16List> masukkan(Uint8List byte) sync* {
    _sisa.add(byte);
    const perPotongan = sampelPerPotongan * 2;
    if (_sisa.length < perPotongan) return;

    final semua = _sisa.takeBytes();
    var i = 0;
    for (; i + perPotongan <= semua.length; i += perPotongan) {
      // Disalin ke Int16List yang selaras; view langsung bisa tidak selaras.
      final potongan = Int16List(sampelPerPotongan);
      final data = ByteData.sublistView(semua, i, i + perPotongan);
      for (var s = 0; s < sampelPerPotongan; s++) {
        potongan[s] = data.getInt16(s * 2, Endian.little);
      }
      yield potongan;
    }
    if (i < semua.length) _sisa.add(Uint8List.sublistView(semua, i));
  }
}

// --- Pendeteksi suara --------------------------------------------------------

/// Kirim hanya saat ada yang bicara.
///
/// Di atas motor, diam jauh lebih banyak daripada bicara. Mengirim diam
/// berarti menghabiskan kuota dan baterai untuk desis angin. Ambangnya
/// mengikuti bising latar yang berubah-ubah — jalan tol dan gang kampung
/// tidak sama bisingnya.
class PendeteksiSuara {
  /// Perkiraan bising latar, RMS.
  double _lantai = 200;

  /// Sisa potongan yang tetap dikirim setelah suara terakhir: ekor kata dan
  /// jeda antar kalimat tidak terpotong.
  int _sisaEkor = 0;

  static const int _panjangEkor = 10; // 400 ms
  static const double _ambangMinimal = 350;

  /// Potongan terakhir yang tidak terkirim, disimpan supaya suku kata
  /// pertama tidak terpotong saat orang mulai bicara.
  Int16List? _sebelumnya;

  /// Potongan yang perlu dikirim untuk [potongan] ini — bisa kosong, satu,
  /// atau dua (dengan potongan sebelumnya sebagai awalan).
  List<Int16List> saring(Int16List potongan) {
    final rms = rmsDari(potongan);
    final bicara = rms > math.max(_ambangMinimal, _lantai * 2.5);

    if (!bicara) {
      // Lantai turun cepat, naik pelan: bising yang tiba-tiba (klakson)
      // tidak langsung dianggap latar.
      _lantai = rms < _lantai ? _lantai * 0.9 + rms * 0.1 : _lantai * 0.995 + rms * 0.005;
    }

    if (bicara) {
      final awalan = _sisaEkor == 0 ? _sebelumnya : null;
      _sisaEkor = _panjangEkor;
      _sebelumnya = null;
      return [?awalan, potongan];
    }

    if (_sisaEkor > 0) {
      _sisaEkor--;
      return [potongan];
    }

    _sebelumnya = potongan;
    return const [];
  }

  static double rmsDari(Int16List pcm) {
    if (pcm.isEmpty) return 0;
    var jumlah = 0.0;
    for (final s in pcm) {
      jumlah += s * s;
    }
    return math.sqrt(jumlah / pcm.length);
  }
}

// --- Pencampur ---------------------------------------------------------------

class _Pembicara {
  final antrean = Queue<Int16List>();
  bool diputar = false;
  DateTime terakhir = DateTime.fromMillisecondsSinceEpoch(0);
}

/// Mencampur suara semua teman jadi satu aliran untuk speaker.
///
/// Tiap orang punya antrean sendiri (penyangga jitter): suara baru diputar
/// setelah tiga potongan (120 ms) terkumpul, supaya sinyal yang
/// tersendat-sendat tidak terdengar patah-patah. Antrean dibatasi 480 ms —
/// lebih dari itu, yang lama dibuang. Obrolan yang tertinggal setengah detik
/// masih bisa dijawab; yang tertinggal tiga detik sudah basi.
class PencampurSuara {
  static const int _mulaiSetelah = 3;
  static const int _antreanMaks = 12;

  final _pembicara = <String, _Pembicara>{};

  void terima(String userId, Int16List potongan, {DateTime? pada}) {
    final p = _pembicara.putIfAbsent(userId, _Pembicara.new);
    p.antrean.add(potongan);
    p.terakhir = pada ?? DateTime.now();
    while (p.antrean.length > _antreanMaks) {
      p.antrean.removeFirst();
    }
  }

  /// Satu potongan campuran. Diam kalau tidak ada yang bicara.
  Int16List ambil() {
    final hasil = Int32List(sampelPerPotongan);

    for (final p in _pembicara.values) {
      if (!p.diputar && p.antrean.length >= _mulaiSetelah) p.diputar = true;
      if (!p.diputar) continue;
      if (p.antrean.isEmpty) {
        // Habis: kumpulkan lagi dulu sebelum lanjut memutar.
        p.diputar = false;
        continue;
      }
      final potongan = p.antrean.removeFirst();
      for (var i = 0; i < potongan.length && i < sampelPerPotongan; i++) {
        hasil[i] += potongan[i];
      }
    }

    return Int16List.fromList([
      for (final s in hasil) s.clamp(-32768, 32767),
    ]);
  }

  /// Siapa yang terdengar bicara dalam [jendela] terakhir.
  Set<String> yangBicara({
    Duration jendela = const Duration(milliseconds: 400),
    DateTime? sekarang,
  }) {
    final kini = sekarang ?? DateTime.now();
    return {
      for (final e in _pembicara.entries)
        if (kini.difference(e.value.terakhir) <= jendela) e.key,
    };
  }

  void lupakan(String userId) => _pembicara.remove(userId);

  void kosongkan() => _pembicara.clear();
}
