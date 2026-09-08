import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:science_cup_app/features/game/application/game_repository_provider.dart';
import 'package:science_cup_app/features/game/data/models/game_summary.dart';

part 'games_notifier.g.dart';

@riverpod
class GamesNotifier extends _$GamesNotifier {
  @override
  Future<List<GameSummary>> build(int seasonId) async {
    final gameRepo = ref.read(gameRepositoryProvider);
    final result = await gameRepo.getGamesForSeason(seasonId);
    return result;
  }

  Future<void> deleteGame(int id) async {
    try {
      await ref.read(gameRepositoryProvider).deleteGame(id);
      ref.invalidateSelf();
    } catch (e, stackTrace) {
      state = AsyncError('Kunne ikke slette kamp: $e', stackTrace);
    }
  }
}
