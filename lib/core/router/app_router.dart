import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/kode_page.dart';
import '../../features/auth/presentation/masuk_page.dart';
import '../../features/auth/presentation/pengaturan_page.dart';
import '../../features/groups/presentation/bareng_page.dart';
import '../../features/groups/presentation/trip_bareng_page.dart';
import '../../features/recap/presentation/recap_page.dart';
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
            path: '/pengaturan',
            pageBuilder: (context, state) =>
                MemudarSilang(child: const PengaturanPage()),
          ),
        ],
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
