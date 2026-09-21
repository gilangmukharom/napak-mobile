import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/napak_colors.dart';
import '../../../core/theme/napak_motion.dart';
import '../../sosial/presentation/komponen_sosial.dart';
import '../data/obrolan_data.dart';

/// Satu ruang obrolan — berdua, atau seluruh rombongan.
class ObrolanPage extends ConsumerStatefulWidget {
  const ObrolanPage({
    required this.percakapanId,
    this.judul,
    this.rombongan = false,
    super.key,
  });

  final String percakapanId;
  final String? judul;
  final bool rombongan;

  @override
  ConsumerState<ObrolanPage> createState() => _ObrolanPageState();
}

class _ObrolanPageState extends ConsumerState<ObrolanPage> {
  late final ObrolanSocket _socket;
  final _masukan = TextEditingController();
  final _gulir = ScrollController();
  final _langganan = <StreamSubscription<dynamic>>[];

  /// Terbaru di depan, karena daftarnya digambar terbalik dari bawah.
  List<Pesan> _pesan = [];
  bool _memuat = true;
  bool _memuatLama = false;
  bool _habis = false;
  String? _galat;

  /// Pesan yang baru masuk selama layar ini terbuka. Hanya mereka yang
  /// dianimasikan masuk — riwayat lama yang dimuat tidak perlu ikut
  /// berjatuhan satu per satu.
  final _baruMasuk = <String>{};

  String? _yangMengetik;
  Timer? _hapusMengetik;
  DateTime _terakhirKirimMengetik = DateTime(2000);

  String? _idSaya;

  @override
  void initState() {
    super.initState();
    _socket = ObrolanSocket(
      alamatDasar: ref.read(apiClientProvider).alamatDasar,
      ambilToken: ref.read(tokenStoreProvider).readAccessToken,
    );

    _langganan.addAll([
      _socket.pesan.listen(_terimaPesan),
      _socket.mengetik.listen((m) {
        if (m.userId == _idSaya) return;
        setState(() => _yangMengetik = m.nama);
        _hapusMengetik?.cancel();
        // Tanda mengetik padam sendiri. Kalau bergantung pada kabar "sudah
        // berhenti", satu kabar yang hilang di jalan membuat tandanya menyala
        // selamanya.
        _hapusMengetik = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _yangMengetik = null);
        });
      }),
      _socket.galat.listen((g) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(g)));
        }
      }),
    ]);

    _gulir.addListener(() {
      // Mendekati ujung atas → muat yang lebih lama.
      if (_gulir.position.pixels > _gulir.position.maxScrollExtent - 240) {
        _muatLebihLama();
      }
    });

    unawaited(_mulai());
  }

  Future<void> _mulai() async {
    _idSaya = await ref.read(idSayaProvider.future);
    final repo = ref.read(obrolanRepositoryProvider);

    try {
      final riwayat = await repo.riwayat(widget.percakapanId);
      if (!mounted) return;
      setState(() {
        _pesan = riwayat;
        _memuat = false;
        _habis = riwayat.length < 50;
      });
      unawaited(repo.tandaiDibaca(widget.percakapanId));
    } catch (error) {
      if (mounted) {
        setState(() {
          _memuat = false;
          _galat = error.toString();
        });
      }
    }

    await _socket.masuk(widget.percakapanId);
  }

  Future<void> _muatLebihLama() async {
    if (_memuatLama || _habis || _pesan.isEmpty) return;
    _memuatLama = true;
    try {
      final lama = await ref
          .read(obrolanRepositoryProvider)
          .riwayat(widget.percakapanId, sebelum: _pesan.last.dibuat);
      if (!mounted) return;
      setState(() {
        _pesan = [..._pesan, ...lama];
        _habis = lama.length < 50;
      });
    } finally {
      _memuatLama = false;
    }
  }

  void _terimaPesan(Pesan p) {
    if (!mounted) return;
    setState(() {
      // Pesan sendiri yang kembali dari server menggantikan salinan
      // "sedang dikirim" — dicocokkan lewat isi dan pengirimnya, karena
      // idnya memang baru ada setelah server menyimpannya.
      final sementara = _pesan.indexWhere(
        (x) => x.sedangDikirim && x.isi == p.isi && p.pengirimId == _idSaya,
      );
      if (sementara >= 0) {
        _pesan = [..._pesan]..[sementara] = p;
      } else if (!_pesan.any((x) => x.id == p.id)) {
        _pesan = [p, ..._pesan];
        _baruMasuk.add(p.id);
        if (p.pengirimId != _idSaya) {
          HapticFeedback.selectionClick();
          _yangMengetik = null;
        }
      }
    });
    unawaited(
      ref.read(obrolanRepositoryProvider).tandaiDibaca(widget.percakapanId),
    );
  }

  Future<void> _kirim() async {
    final isi = _masukan.text.trim();
    if (isi.isEmpty) return;
    _masukan.clear();
    HapticFeedback.lightImpact();

    final sementara = Pesan(
      id: 'sementara-${DateTime.now().microsecondsSinceEpoch}',
      percakapanId: widget.percakapanId,
      pengirimId: _idSaya,
      namaPengirim: 'Kamu',
      isi: isi,
      dibuat: DateTime.now(),
      sedangDikirim: true,
    );
    setState(() {
      _pesan = [sementara, ..._pesan];
      _baruMasuk.add(sementara.id);
    });

    if (_socket.aktif) {
      _socket.kirim(isi);
      return;
    }

    // Socket-nya sedang putus — di jalan, itu keadaan normal. Lewat HTTP.
    try {
      final tersimpan = await ref
          .read(obrolanRepositoryProvider)
          .kirim(widget.percakapanId, isi);
      _terimaPesan(tersimpan);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pesan = [
          for (final x in _pesan)
            x.id == sementara.id
                ? Pesan(
                    id: x.id,
                    percakapanId: x.percakapanId,
                    pengirimId: x.pengirimId,
                    namaPengirim: x.namaPengirim,
                    isi: x.isi,
                    dibuat: x.dibuat,
                    gagal: true,
                  )
                : x,
        ];
      });
    }
  }

  void _saatMengetik(String _) {
    setState(() {});
    // Kabar mengetik paling sering sekali tiap dua detik; tiap huruf
    // mengirim kabar sama saja dengan membanjiri rombongan.
    final sekarang = DateTime.now();
    if (sekarang.difference(_terakhirKirimMengetik).inSeconds >= 2) {
      _terakhirKirimMengetik = sekarang;
      _socket.sedangMengetik();
    }
  }

  @override
  void dispose() {
    for (final l in _langganan) {
      l.cancel();
    }
    _hapusMengetik?.cancel();
    unawaited(_socket.tutup());
    _masukan.dispose();
    _gulir.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Dibuka dari tautan di inbox, judulnya belum ikut dibawa — diambil dari
    // daftar obrolan yang toh sudah tersimpan di memori.
    final dariDaftar = widget.judul == null
        ? (ref.watch(daftarObrolanProvider).value ?? const <Percakapan>[])
              .where((p) => p.id == widget.percakapanId)
              .firstOrNull
        : null;
    final judul = widget.judul ?? dariDaftar?.judul ?? 'Obrolan';
    final rombongan = widget.rombongan || (dariDaftar?.rombongan ?? false);

    return Scaffold(
      backgroundColor: NapakColors.base,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Hero(
              tag: 'obrolan-${widget.percakapanId}',
              child: rombongan
                  ? const _LingkaranRombongan(ukuran: 38)
                  : LingkaranNama(
                      nama: judul,
                      ukuran: 38,
                      cincin: _yangMengetik != null,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    judul,
                    style: text.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AnimatedSwitcher(
                    duration: NapakMotion.cepat,
                    child: _yangMengetik == null
                        ? Text(
                            rombongan ? 'Obrolan rombongan' : 'Teman',
                            key: const ValueKey('diam'),
                            style: text.bodySmall,
                          )
                        : Text(
                            rombongan
                                ? '$_yangMengetik sedang mengetik…'
                                : 'sedang mengetik…',
                            key: const ValueKey('ketik'),
                            style: text.bodySmall?.copyWith(
                              color: NapakColors.deepAccent,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _isi(text)),
          AnimatedSize(
            duration: NapakMotion.cepat,
            curve: NapakMotion.mengalir,
            child: _yangMengetik == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _TitikMengetik(),
                    ),
                  ),
          ),
          _BilahTulis(
            pengendali: _masukan,
            onBerubah: _saatMengetik,
            onKirim: _kirim,
          ),
        ],
      ),
    );
  }

  Widget _isi(TextTheme text) {
    if (_memuat) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_galat != null) {
      return KosongHangat(
        ikon: Icons.cloud_off_rounded,
        judul: 'Obrolannya belum bisa dibuka',
        isi: _galat!,
      );
    }
    if (_pesan.isEmpty) {
      return KosongHangat(
        ikon: Icons.waving_hand_outlined,
        judul: 'Mulai obrolannya',
        isi: widget.rombongan
            ? 'Sapa rombonganmu. Titik kumpul, jam berangkat, siapa bawa apa.'
            : 'Sapa temanmu. Mungkin ajak menyusun perjalanan berikutnya.',
      );
    }

    return ListView.builder(
      controller: _gulir,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      itemCount: _pesan.length,
      itemBuilder: (context, i) {
        final p = _pesan[i];
        final lebihLama = i + 1 < _pesan.length ? _pesan[i + 1] : null;
        final lebihBaru = i > 0 ? _pesan[i - 1] : null;

        final milikSaya = p.pengirimId != null && p.pengirimId == _idSaya;
        final hariBaru =
            lebihLama == null || !_hariSama(lebihLama.dibuat, p.dibuat);

        // Gelembung berturut-turut dari orang yang sama dirapatkan dan
        // namanya tidak diulang, seperti obrolan di aplikasi mana pun.
        final awalRentetan = hariBaru || lebihLama.pengirimId != p.pengirimId;
        final akhirRentetan =
            lebihBaru == null ||
            lebihBaru.pengirimId != p.pengirimId ||
            !_hariSama(lebihBaru.dibuat, p.dibuat);

        final gelembung = _Gelembung(
          pesan: p,
          milikSaya: milikSaya,
          tampilkanNama: widget.rombongan && !milikSaya && awalRentetan,
          awalRentetan: awalRentetan,
          akhirRentetan: akhirRentetan,
          animasikan: _baruMasuk.contains(p.id),
        );

        return Column(
          children: [
            if (hariBaru) _PemisahHari(tanggal: p.dibuat),
            gelembung,
          ],
        );
      },
    );
  }

  static bool _hariSama(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _LingkaranRombongan extends StatelessWidget {
  const _LingkaranRombongan({required this.ukuran});

  final double ukuran;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ukuran,
      height: ukuran,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: NapakColors.routeGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.two_wheeler_rounded,
        color: NapakColors.textOnDeep,
        size: ukuran * 0.5,
      ),
    );
  }
}

class _PemisahHari extends StatelessWidget {
  const _PemisahHari({required this.tanggal});

  final DateTime tanggal;

  @override
  Widget build(BuildContext context) {
    final kini = DateTime.now();
    final kemarin = kini.subtract(const Duration(days: 1));
    final teks = _sama(tanggal, kini)
        ? 'Hari ini'
        : _sama(tanggal, kemarin)
        ? 'Kemarin'
        : DateFormat('EEEE, d MMMM', 'id_ID').format(tanggal);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: NapakColors.softSky,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          teks,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: NapakColors.deepAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static bool _sama(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Gelembung extends StatelessWidget {
  const _Gelembung({
    required this.pesan,
    required this.milikSaya,
    required this.tampilkanNama,
    required this.awalRentetan,
    required this.akhirRentetan,
    required this.animasikan,
  });

  final Pesan pesan;
  final bool milikSaya;
  final bool tampilkanNama;
  final bool awalRentetan;
  final bool akhirRentetan;
  final bool animasikan;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const besar = Radius.circular(20);
    const kecil = Radius.circular(6);

    // Sudut di sisi pengirim mengecil di tengah rentetan, sehingga
    // gelembung berturut-turut terbaca sebagai satu tumpukan.
    final sudut = milikSaya
        ? BorderRadius.only(
            topLeft: besar,
            bottomLeft: besar,
            topRight: awalRentetan ? besar : kecil,
            bottomRight: akhirRentetan ? besar : kecil,
          )
        : BorderRadius.only(
            topRight: besar,
            bottomRight: besar,
            topLeft: awalRentetan ? besar : kecil,
            bottomLeft: akhirRentetan ? besar : kecil,
          );

    final isi = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.76,
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        gradient: milikSaya
            ? const LinearGradient(
                colors: NapakColors.routeGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: milikSaya ? null : Colors.white,
        borderRadius: sudut,
        boxShadow: milikSaya
            ? null
            : [
                BoxShadow(
                  color: NapakColors.textPrimary.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tampilkanNama)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                pesan.namaPengirim,
                style: text.labelSmall?.copyWith(
                  color: NapakColors.deepAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text(
                pesan.isi,
                style: text.bodyMedium?.copyWith(
                  color: milikSaya
                      ? NapakColors.textOnDeep
                      : NapakColors.textPrimary,
                  height: 1.35,
                ),
              ),
              _StempelWaktu(pesan: pesan, milikSaya: milikSaya),
            ],
          ),
        ],
      ),
    );

    final baris = Padding(
      padding: EdgeInsets.only(top: awalRentetan ? 8 : 2),
      child: Row(
        mainAxisAlignment: milikSaya
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AnimatedOpacity(
            duration: NapakMotion.cepat,
            opacity: pesan.sedangDikirim ? 0.6 : 1,
            child: isi,
          ),
        ],
      ),
    );

    if (!animasikan) return baris;

    // Gelembung baru meluncur dari sisi pengirimnya dan sedikit memantul —
    // cukup untuk terasa "sampai", tidak cukup untuk jadi atraksi.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: NapakMotion.sedang,
      curve: NapakMotion.memantul,
      builder: (context, t, anak) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset((1 - t) * (milikSaya ? 28 : -28), (1 - t) * 10),
          child: Transform.scale(
            scale: 0.9 + 0.1 * t,
            alignment: milikSaya ? Alignment.bottomRight : Alignment.bottomLeft,
            child: anak,
          ),
        ),
      ),
      child: baris,
    );
  }
}

class _StempelWaktu extends StatelessWidget {
  const _StempelWaktu({required this.pesan, required this.milikSaya});

  final Pesan pesan;
  final bool milikSaya;

  @override
  Widget build(BuildContext context) {
    final warna = milikSaya
        ? NapakColors.textOnDeep.withValues(alpha: 0.8)
        : NapakColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('HH:mm').format(pesan.dibuat),
            style: TextStyle(fontSize: 10.5, color: warna),
          ),
          if (milikSaya) ...[
            const SizedBox(width: 3),
            Icon(
              pesan.gagal
                  ? Icons.error_outline_rounded
                  : pesan.sedangDikirim
                  ? Icons.schedule_rounded
                  : Icons.done_rounded,
              size: 13,
              color: pesan.gagal ? NapakColors.attention : warna,
            ),
          ],
        ],
      ),
    );
  }
}

/// Tiga titik yang naik-turun bergantian.
class _TitikMengetik extends StatefulWidget {
  @override
  State<_TitikMengetik> createState() => _TitikMengetikState();
}

class _TitikMengetikState extends State<_TitikMengetik>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Transform.translate(
                  offset: Offset(
                    0,
                    -4 *
                        math.max(
                          0,
                          math.sin((_c.value - i * 0.18) * 2 * math.pi),
                        ),
                  ),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: NapakColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BilahTulis extends StatelessWidget {
  const _BilahTulis({
    required this.pengendali,
    required this.onBerubah,
    required this.onKirim,
  });

  final TextEditingController pengendali;
  final ValueChanged<String> onBerubah;
  final VoidCallback onKirim;

  @override
  Widget build(BuildContext context) {
    final adaIsi = pengendali.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        10,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: NapakColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: pengendali,
              onChanged: onBerubah,
              minLines: 1,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Tulis pesan…',
                counterText: '',
                filled: true,
                fillColor: NapakColors.base,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Tombol kirim membesar dan berwarna penuh begitu ada yang ditulis.
          AnimatedScale(
            duration: NapakMotion.cepat,
            curve: NapakMotion.memantul,
            scale: adaIsi ? 1 : 0.86,
            child: AnimatedContainer(
              duration: NapakMotion.cepat,
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: adaIsi ? NapakColors.ember : NapakColors.softSky,
              ),
              child: IconButton(
                onPressed: adaIsi ? onKirim : null,
                icon: AnimatedRotation(
                  duration: NapakMotion.sedang,
                  curve: NapakMotion.memantul,
                  turns: adaIsi ? 0 : -0.1,
                  child: Icon(
                    Icons.send_rounded,
                    size: 20,
                    color: adaIsi ? NapakColors.malam : NapakColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
