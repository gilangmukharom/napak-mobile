import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../../../core/widgets/tourvella_gerak.dart';
import '../../../core/widgets/tourvella_pressable.dart';
import '../application/intercom_controller.dart';
import '../data/intercom_service.dart';

/// Intercom rombongan, dalam satu kartu.
///
/// Dirancang untuk sarung tangan: tombol bisu dan keluar besar, dan tidak ada
/// yang perlu dibaca teliti. Siapa yang sedang bicara terlihat dari cincin di
/// inisialnya, bukan dari tulisan.
class PanelIntercom extends ConsumerWidget {
  const PanelIntercom({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intercom = ref.watch(intercomControllerProvider);
    final aksi = ref.read(intercomControllerProvider.notifier);
    final diRuangIni = intercom.tripId == tripId;

    ref.listen(intercomControllerProvider.select((s) => s.pesan), (_, pesan) {
      if (pesan == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
      aksi.hapusPesan();
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: TourvellaColors.base.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: TourvellaColors.textPrimary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: TourvellaMotion.sedang,
        switchInCurve: TourvellaMotion.mengalir,
        child: diRuangIni
            ? _RuangAktif(key: const ValueKey('aktif'), intercom: intercom)
            : _Ajakan(
                key: const ValueKey('ajakan'),
                // Intercom rombongan lain yang masih menyala dimatikan dulu:
                // satu mikrofon, satu ruang.
                onGabung: () async {
                  if (intercom.aktif) await aksi.keluar();
                  await aksi.gabung(tripId);
                },
              ),
      ),
    );
  }
}

class _Ajakan extends StatelessWidget {
  const _Ajakan({required this.onGabung, super.key});

  final VoidCallback onGabung;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: const BoxDecoration(
            color: TourvellaColors.softSky,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.headset_mic_rounded,
            color: TourvellaColors.deepAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Intercom rombongan',
                style: text.titleSmall?.copyWith(
                  color: TourvellaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Ngobrol sambil jalan. Suaramu tidak pernah direkam.',
                style: text.bodySmall?.copyWith(
                  color: TourvellaColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: onGabung, child: const Text('Gabung')),
      ],
    );
  }
}

class _RuangAktif extends ConsumerWidget {
  const _RuangAktif({required this.intercom, super.key});

  final IntercomState intercom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aksi = ref.read(intercomControllerProvider.notifier);
    final text = Theme.of(context).textTheme;
    final teman = intercom.anggota;

    final keterangan = intercom.menyambung
        ? 'Menyambungkan…'
        : !intercom.tersambung
        ? 'Sinyal putus, menyambung lagi…'
        : intercom.bisu
        ? 'Mikrofonmu bisu — suaramu tidak dikirim'
        : teman.length <= 1
        ? 'Menunggu teman bergabung'
        : '${teman.length} orang di intercom';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  TitikBerdenyut(
                    warna: intercom.tersambung
                        ? TourvellaColors.affirm
                        : TourvellaColors.textSecondary,
                    ukuran: 8,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      keterangan,
                      style: text.labelMedium?.copyWith(
                        color: TourvellaColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final a in teman)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _Inisial(
                          anggota: a,
                          bicara: intercom.bicara.contains(a.userId),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _TombolBulat(
          ikon: intercom.bisu ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: intercom.bisu ? 'Nyalakan mikrofon' : 'Bisukan mikrofon',
          latar: intercom.bisu
              ? TourvellaColors.attention.withValues(alpha: 0.18)
              : TourvellaColors.softSky,
          warna: intercom.bisu
              ? TourvellaColors.attention
              : TourvellaColors.deepAccent,
          // Cincin tipis saat suaramu sendiri sedang terkirim.
          cincin: intercom.sayaBicara ? TourvellaColors.affirm : null,
          onTap: () => aksi.aturBisu(!intercom.bisu),
        ),
        const SizedBox(width: 8),
        _TombolBulat(
          ikon: Icons.call_end_rounded,
          label: 'Keluar dari intercom',
          latar: TourvellaColors.attention,
          warna: TourvellaColors.textOnDeep,
          onTap: aksi.keluar,
        ),
      ],
    );
  }
}

class _Inisial extends StatelessWidget {
  const _Inisial({required this.anggota, required this.bicara});

  final AnggotaSuara anggota;
  final bool bicara;

  @override
  Widget build(BuildContext context) {
    final huruf = anggota.nama.trim().isEmpty
        ? '?'
        : anggota.nama.trim()[0].toUpperCase();

    return Tooltip(
      message: anggota.nama,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: TourvellaMotion.cepat,
            curve: TourvellaMotion.mengalir,
            height: 40,
            width: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TourvellaColors.softSky,
              shape: BoxShape.circle,
              border: Border.all(
                color: bicara ? TourvellaColors.affirm : Colors.transparent,
                width: 3,
              ),
            ),
            child: Text(
              huruf,
              style: const TextStyle(
                color: TourvellaColors.deepAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (anggota.bisu)
            const Positioned(
              right: -2,
              bottom: -2,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: TourvellaColors.base,
                child: Icon(
                  Icons.mic_off_rounded,
                  size: 11,
                  color: TourvellaColors.attention,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TombolBulat extends StatelessWidget {
  const _TombolBulat({
    required this.ikon,
    required this.label,
    required this.latar,
    required this.warna,
    required this.onTap,
    this.cincin,
  });

  final IconData ikon;
  final String label;
  final Color latar;
  final Color warna;
  final Color? cincin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: TourvellaPressable(
        skala: 0.9,
        onTap: onTap,
        child: AnimatedContainer(
          duration: TourvellaMotion.cepat,
          curve: TourvellaMotion.mengalir,
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            color: latar,
            shape: BoxShape.circle,
            border: Border.all(
              color: cincin ?? Colors.transparent,
              width: 3,
            ),
          ),
          child: Icon(ikon, color: warna, size: 24),
        ),
      ),
    );
  }
}
