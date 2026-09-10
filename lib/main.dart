import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:intl/date_symbol_data_local.dart';
import 'package:science_cup_app/core/storage/shared_preferences_provider.dart';
import 'package:science_cup_app/flavors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/navigation/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kører man `main.dart` direkte (uden at gå via main_dev.dart/
  // main_prod.dart), er der ikke sat en flavor endnu — falder tilbage til
  // dev, som er den hidtidige standardopførsel.
  if (!F.appFlavorIsSet) {
    F.appFlavor = Flavor.dev;
  }

  final prefs = await SharedPreferences.getInstance();

  await initializeDateFormatting('da_DK', null);

  final envFile = F.appFlavor == Flavor.prod ? ".env.prod" : ".env.dev";
  await dotenv.load(fileName: envFile);

  Supabase.initialize(
    /// TODO: These should be set with env vars in a github action
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_PUBLIC_KEY']!,
    authOptions: FlutterAuthClientOptions(
      // DETTE ER MAGIEN, DER GEMMER DIT LOGIN:
      localStorage: SharedPreferencesLocalStorage(
        persistSessionKey: "science_cup_app_session",
      ),
    ),
  );

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      locale: const Locale("da", "DK"),
      supportedLocales: const [
        Locale('da', 'DK'), // Dansk
        Locale('en', 'US'), // Engelsk (god at have som fallback)
      ],

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(appRouterProvider),
      title: 'Science Cup\'en',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
    );
  }
}
