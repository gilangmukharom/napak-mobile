import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tanggal ditulis dalam Bahasa Indonesia: "Sabtu, 20 September 2026",
  // bukan "Saturday, September 20".
  await initializeDateFormatting('id_ID');

  runApp(const ProviderScope(child: NapakApp()));
}
