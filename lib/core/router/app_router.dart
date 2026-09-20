import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/kode_page.dart';
import '../../features/auth/presentation/masuk_page.dart';
import '../../features/auth/presentation/pengaturan_page.dart';
import '../../features/groups/presentation/trip_bareng_page.dart';
import '../../features/recap/presentation/recap_page.dart';
import '../../features/trips/presentation/beranda_page.dart';
import '../../features/trips/presentation/trip_detail_page.dart';
import '../providers.dart';
import '../theme/napak_colors.dart';

/// Rute aplikasi.
///
/// Pengalihan ke halaman masuk dikerjakan di satu tempat ini saja — supaya
/// tidak ada halaman yang tanpa sengaja bisa dibuka tanpa sesi.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final sesi = ref.read(sessionProvider);

      // Masih memeriksa penyimpanan aman; tahan dulu di layar pembuka.
      if (sesi.isLoading) return null;

      final punyaSesi = sesi.value ?? false;
      final sedangMasuk = state.matchedLocation.startsWith('/masuk');

      if (!punyaSesi && !sedangMasuk) return '/masuk';
      if (punyaSesi && sedangMasuk) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const BerandaPage()),
      GoRoute(
        path: '/masuk',
        builder: (context, state) => const MasukPage(),
        routes: [
          GoRoute(
            path: 'kode',
            builder: (context, state) =>
                KodePage(phoneNumber: state.extra! as String),
          ),
        ],
      ),
      GoRoute(
        path: '/trip/:id',
        builder: (context, state) =>
            TripDetailPage(tripId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'bareng',
            builder: (context, state) =>
                TripBarengPage(tripId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/recap',
        builder: (context, state) {
          final tahun = int.tryParse(state.uri.queryParameters['tahun'] ?? '');
          return RecapPage(tahun: tahun);
        },
      ),
      GoRoute(
        path: '/pengaturan',
        builder: (context, state) => const PengaturanPage(),
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
