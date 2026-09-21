import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/kode_page.dart';
import '../../features/auth/presentation/masuk_page.dart';
import '../../features/auth/presentation/pengaturan_page.dart';
import '../../features/groups/presentation/bareng_page.dart';
import '../../features/groups/presentation/trip_bareng_page.dart';
import '../../features/obrolan/presentation/daftar_obrolan_page.dart';
import '../../features/profil/presentation/edit_profil_page.dart';
import '../../features/profil/presentation/profil_page.dart';
import '../../features/obrolan/presentation/obrolan_page.dart';
import '../../features/peta/presentation/peta_offline_page.dart';
import '../../features/recap/presentation/jejak_nusantara_page.dart';
import '../../features/recap/presentation/recap_page.dart';
import '../../features/sosial/presentation/inbox_page.dart';
import '../../features/sosial/presentation/kartu_pos_page.dart';
import '../../features/sosial/presentation/teman_page.dart';
import '../../features/recording/presentation/mulai_rekam_page.dart';
import '../../features/recording/presentation/rekam_page.dart';
import '../../features/splash/presentation/splash_page.dart';
import '../../features/trips/presentation/beranda_page.dart';
import '../../features/trips/presentation/cerita_page.dart';
import '../../features/trips/presentation/trip_detail_page.dart';
import '../providers.dart';
import '../theme/napak_colors.dart';
import '../theme/napak_motion.dart';
import '../widgets/napak_shell.dart';

/// Rute aplikasi.
///
/// Pengalihan sesi dikerjakan di satu tempat ini saja — supaya tidak ada
/// halaman yang tanpa sengaja bisa dibuka tanpa login.
///
/// Empat tab utama hidup di dalam [NapakShell] lewat ShellRoute, jadi bilah
/// navigasinya tidak ikut dibangun ulang tiap berpindah tab. Halaman yang
/// lebih dalam (detail perjalanan, perekaman) ditumpuk di atasnya dan menutupi
/// bilah itu — menandakan kamu sedang masuk ke dalam sesuatu, bukan berpindah
/// ke samping.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/pembuka',
    redirect: (context, state) {
      final sesi = ref.read(sessionProvider);
      final jalur = state.matchedLocation;

      // Layar pembuka yang memutuskan ke mana setelah sesinya ketahuan.
      // Kalau redirect ikut campur di sini, animasinya terpotong.
      if (jalur == '/pembuka') return null;

      if (sesi.isLoading) return null;

      final punyaSesi = sesi.value ?? false;
      final sedangMasuk = jalur.startsWith('/masuk');

      if (!punyaSesi && !sedangMasuk) return '/masuk';
      if (punyaSesi && sedangMasuk) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/pembuka',
        pageBuilder: (context, state) =>
            MemudarSilang(child: const SplashPage()),
      ),

      GoRoute(
        path: '/masuk',
        pageBuilder: (context, state) => NaikMasuk(child: const MasukPage()),
        routes: [
          GoRoute(
            path: 'kode',
            pageBuilder: (context, state) =>
                GeserMasuk(child: KodePage(phoneNumber: state.extra! as String)),
          ),
        ],
      ),

      // --- Empat tab utama ---
      ShellRoute(
        builder: (context, state, child) => NapakShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                MemudarSilang(child: const BerandaPage()),
          ),
          GoRoute(
            path: '/bareng',
            pageBuilder: (context, state) =>
                MemudarSilang(child: const BarengPage()),
          ),
          GoRoute(
            path: '/recap',
            pageBuilder: (context, state) {
              final tahun = int.tryParse(
                state.uri.queryParameters['tahun'] ?? '',
              );
              return MemudarSilang(child: RecapPage(tahun: tahun));
            },
          ),
          GoRoute(
            path: '/profil',
            pageBuilder: (context, state) =>
                MemudarSilang(child: const ProfilPage(id: 'saya')),
          ),
        ],
      ),

      // Pengaturan dan privasi, dibuka dari menu di profil.
      GoRoute(
        path: '/pengaturan',
        pageBuilder: (context, state) =>
            GeserMasuk(child: const PengaturanPage()),
      ),
      GoRoute(
        path: '/profil/edit',
        pageBuilder: (context, state) =>
            NaikMasuk(child: const EditProfilPage()),
      ),
      GoRoute(
        path: '/orang/:id',
        pageBuilder: (context, state) => GeserMasuk(
          child: ProfilPage(id: state.pathParameters['id']!),
        ),
      ),

      // --- Halaman yang ditumpuk di atas tab ---
      GoRoute(
        path: '/trip/:id',
        pageBuilder: (context, state) =>
            GeserMasuk(child: TripDetailPage(tripId: state.pathParameters['id']!)),
        routes: [
          GoRoute(
            path: 'bareng',
            pageBuilder: (context, state) => GeserMasuk(
              child: TripBarengPage(tripId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'cerita',
            pageBuilder: (context, state) => NaikMasuk(
              child: CeritaPage(tripId: state.pathParameters['id']!),
            ),
          ),
        ],
      ),

      // --- Sisi sosial ---
      GoRoute(
        path: '/teman',
        pageBuilder: (context, state) => GeserMasuk(child: const TemanPage()),
      ),
      GoRoute(
        path: '/inbox',
        pageBuilder: (context, state) => GeserMasuk(child: const InboxPage()),
      ),
      GoRoute(
        path: '/obrolan',
        pageBuilder: (context, state) =>
            GeserMasuk(child: const DaftarObrolanPage()),
        routes: [
          GoRoute(
            path: ':id',
            pageBuilder: (context, state) {
              // Dibuka dari daftar membawa judulnya; dibuka dari tautan di
              // inbox tidak — halamannya tetap jalan, judulnya menyusul.
              final ekstra = state.extra;
              final (judul, rombongan) = ekstra is ({
                    String judul,
                    bool rombongan,
                  })
                  ? (ekstra.judul, ekstra.rombongan)
                  : (null, false);
              return GeserMasuk(
                child: ObrolanPage(
                  percakapanId: state.pathParameters['id']!,
                  judul: judul,
                  rombongan: rombongan,
                ),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/kartu-pos',
        pageBuilder: (context, state) =>
            GeserMasuk(child: const KotakPosPage()),
        routes: [
          GoRoute(
            path: ':id',
            pageBuilder: (context, state) => NaikMasuk(
              child: KartuPosPage(id: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/peta-offline',
        pageBuilder: (context, state) =>
            GeserMasuk(child: const PetaOfflinePage()),
      ),
      GoRoute(
        path: '/jejak-nusantara',
        pageBuilder: (context, state) =>
            NaikMasuk(child: const JejakNusantaraPage()),
      ),

      GoRoute(
        path: '/rekam',
        pageBuilder: (context, state) => NaikMasuk(child: const RekamPage()),
        routes: [
          GoRoute(
            path: 'mulai',
            pageBuilder: (context, state) =>
                NaikMasuk(child: const MulaiRekamPage()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.explore_off_outlined,
                size: 44,
                color: NapakColors.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Jalan ini buntu',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Kembali ke beranda'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});
