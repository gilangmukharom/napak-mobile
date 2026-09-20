import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/napak_theme.dart';
import 'features/recording/application/sync_service.dart';

class NapakApp extends ConsumerStatefulWidget {
  const NapakApp({super.key});

  @override
  ConsumerState<NapakApp> createState() => _NapakAppState();
}

class _NapakAppState extends ConsumerState<NapakApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Jejak yang tertinggal dari sesi sebelumnya disusulkan begitu aplikasi
    // dibuka lagi, tanpa perlu diminta.
    WidgetsBinding.instance.addPostFrameCallback((_) => _susulkanJejak());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _susulkanJejak();
    }
  }

  Future<void> _susulkanJejak() async {
    if (!(ref.read(sessionProvider).value ?? false)) return;
    await ref.read(syncServiceProvider).flush();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Napak',
      debugShowCheckedModeBanner: false,
      theme: NapakTheme.build(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
