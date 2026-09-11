// lib/app_router.dart
import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:science_cup_app/core/navigation/app_page.dart';
import 'package:science_cup_app/core/navigation/season_tabs.dart';
import 'package:science_cup_app/features/auth/application/auth_notifier.dart';
import 'package:science_cup_app/features/auth/application/auth_state.dart';
import 'package:science_cup_app/features/auth/presentation/login_page.dart';
import 'package:science_cup_app/features/season/application/season/season_notifier.dart';
import 'package:science_cup_app/features/season/data/models/season.dart';
import 'package:science_cup_app/features/season/presentation/season_page.dart';
import 'package:science_cup_app/features/season/presentation/seasons_view.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        // Send brugeren direkte ind i den sæson, hvor i dag ligger mellem
        // start- og slutdato — der skal ikke være en "vælg sæson"-side i
        // vejen. Findes der ingen sæson, der dækker i dag (fx en helt
        // tom/ny database), falder vi tilbage til sæsonlisten nedenfor,
        // så man stadig kan oprette eller vælge en sæson manuelt.
        redirect: (context, state) async {
          try {
            // Vent til den indledende session-tjek (inkl. eventuel
            // oprydning af en forældet/ugyldig session fra en tidligere
            // installation) er afsluttet, før vi henter sæsoner. Ellers
            // risikerer vi at sende kaldet af sted med et access token,
            // der er ved at blive ryddet, hvilket giver en 401 og efterlader
            // sæson-listen i en fejltilstand, der ikke selv retter sig.
            await _waitForAuthReady(ref);

            final seasons = await ref.read(seasonsProvider.future);
            final season = _pickActiveSeason(seasons);
            if (season?.id == null) return null;
            return '/seasons/${season!.id}';
          } catch (_) {
            return null;
          }
        },
        builder: (context, state) => WelcomePage(child: const SeasonsView()),
      ),

      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),

      // Validerer kun ID og omdirigerer til default tab
      GoRoute(
        path: '/seasons/:id',
        redirect: (context, state) {
          final id = state.pathParameters['id']!;
          final parsedId = int.tryParse(id);
          if (parsedId == null) {
            return '/';
          }
          // Omdirigér til default tab – ingen stateændring her
          return '/seasons/$id/${SeasonTabs.defaultTab.path}';
        },
      ),

      // Selve sæsonsiden med tabs
      GoRoute(
        path: '/seasons/:id/:tab',
        redirect: (context, state) {
          final authState = ref.read(authProvider);

          final id = state.pathParameters['id']!;
          final tabPath = state.pathParameters['tab'];
          final activeTab = SeasonTabs.fromPath(tabPath);

          // Læs profil-rolle fra den allerede watched authState
          final profileRole = authState.profileRole;

          if (!SeasonTabs.canAccessTab(activeTab, profileRole)) {
            return '/seasons/$id/${SeasonTabs.defaultTab.path}';
          }

          return null; // Tillad navigation
        },
        builder: (context, state) {
          final seasonId = int.parse(state.pathParameters['id']!);
          final tabPath = state.pathParameters['tab'];
          final activeTab = SeasonTabs.fromPath(tabPath);

          // Returner siden; den vil selv opdatere det aktive seasonId
          return SeasonPage(seasonId: seasonId, activeTab: activeTab);
        },
      ),
    ],
  );
}

/// Venter til [authProvider]s indledende session-tjek er afsluttet
/// (`isLoading` er blevet `false`), så vi ikke henter data, mens en
/// forældet session muligvis stadig er ved at blive ryddet op i baggrunden.
/// Fejler den indledende tjek aldrig af en eller anden grund, giver vi op
/// efter kort tid i stedet for at blokere routing for evigt.
Future<void> _waitForAuthReady(Ref ref) async {
  if (!ref.read(authProvider).isLoading) return;

  final completer = Completer<void>();
  final subscription = ref.listen<AuthState>(authProvider, (previous, next) {
    if (!next.isLoading && !completer.isCompleted) {
      completer.complete();
    }
  });

  try {
    await completer.future.timeout(const Duration(seconds: 5));
  } catch (_) {
    // Timeout — fortsæt alligevel.
  } finally {
    subscription.close();
  }
}

/// Finder den sæson, der bedst repræsenterer "nu":
/// 1. En sæson hvor i dag ligger mellem start- og slutdato.
/// 2. Ellers den senest afsluttede sæson.
/// 3. Ellers den næste kommende sæson.
/// 4. Ellers (ingen datoer at gå ud fra) den senest oprettede sæson.
Season? _pickActiveSeason(List<Season> seasons) {
  if (seasons.isEmpty) return null;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  DateTime? dayOnly(DateTime? d) =>
      d == null ? null : DateTime(d.year, d.month, d.day);

  final current = seasons.where((s) {
    final start = dayOnly(s.startDate);
    final end = dayOnly(s.endDate);
    if (start == null || end == null) return false;
    return !today.isBefore(start) && !today.isAfter(end);
  }).toList();
  if (current.isNotEmpty) {
    // Bør ikke forekomme (overlappende sæsoner), men vælg i så fald den
    // der er startet senest.
    current.sort((a, b) => b.startDate!.compareTo(a.startDate!));
    return current.first;
  }

  final past =
      seasons
          .where((s) => s.endDate != null && s.endDate!.isBefore(today))
          .toList()
        ..sort((a, b) => b.endDate!.compareTo(a.endDate!));
  if (past.isNotEmpty) return past.first;

  final upcoming =
      seasons
          .where((s) => s.startDate != null && s.startDate!.isAfter(today))
          .toList()
        ..sort((a, b) => a.startDate!.compareTo(b.startDate!));
  if (upcoming.isNotEmpty) return upcoming.first;

  final withCreatedAt = seasons.where((s) => s.createdAt != null).toList()
    ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
  if (withCreatedAt.isNotEmpty) return withCreatedAt.first;

  return seasons.first;
}
