// lib/features/season/application/route_season_id_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:science_cup_app/core/navigation/app_router.dart';

part 'route_season_id_provider.g.dart';

@riverpod
int? routeSeasonId(Ref ref) {
  final router = ref.watch(appRouterProvider);
  final routerDelegate = router.routerDelegate;

  // GoRouter kalder ikke automatisk denne provider igen, når man navigerer
  // (currentConfiguration læses kun én gang uden dette). Vi lytter derfor
  // selv på routerDelegate og genberegner providerens værdi ved navigation.
  void listener() => ref.invalidateSelf();
  routerDelegate.addListener(listener);
  ref.onDispose(() => routerDelegate.removeListener(listener));

  final currentConfig = routerDelegate.currentConfiguration; // RouteMatchList
  final uri = currentConfig.uri; // Uri
  final segments = uri.pathSegments; // List<String>

  // Forventet mønster: /seasons/:id/...
  // F.eks. ['seasons', '1', 'games']
  if (segments.length >= 2 && segments[0] == 'seasons') {
    return int.tryParse(segments[1]);
  }
  return null;
}
