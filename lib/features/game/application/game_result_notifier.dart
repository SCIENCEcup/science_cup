// application/notifiers/game_result_notifier.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:science_cup_app/features/game/application/game_provider.dart';
import 'package:science_cup_app/features/game/application/game_repository_provider.dart';
import 'package:science_cup_app/features/game/application/games_notifier.dart';
import 'package:science_cup_app/features/season/application/active_season/current_season_provider.dart';

part 'game_result_notifier.g.dart';

class GameResultState {
  final int? homeScore;
  final int? awayScore;
  final bool isSubmitting;
  final String? errorMessage;
  final bool isInitialLoading;

  const GameResultState({
    this.homeScore,
    this.awayScore,
    this.isSubmitting = false,
    this.errorMessage,
    this.isInitialLoading = true,
  });

  GameResultState copyWith({
    int? homeScore,
    int? awayScore,
    bool? isSubmitting,
    String? errorMessage,
    bool? submittedSuccessfully,
    bool? isInitialLoading,
  }) {
    return GameResultState(
      homeScore: homeScore ?? this.homeScore,
      awayScore: awayScore ?? this.awayScore,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage ?? this.errorMessage,

      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
    );
  }
}

@riverpod
class GameResultNotifier extends _$GameResultNotifier {
  @override
  GameResultState build(int gameId) {
    final gameAsync = ref.watch(gameProvider(gameId));
    final gameResultState = gameAsync.maybeWhen(
      data: (game) => GameResultState(
        homeScore: game.homeScore,
        awayScore: game.awayScore,
        isInitialLoading: false,
      ),
      orElse: () => GameResultState(isInitialLoading: true),
    );
    return gameResultState;
  }

  // copyWith kan ikke nulstille et felt til null (dens `??`-mønster
  // beholder den gamle værdi), så scoren sættes direkte på en ny state i
  // stedet — ellers ville et ryddet felt aldrig kunne gemmes som "intet
  // resultat" igen.
  void setHomeScore(int? score) => state = GameResultState(
    homeScore: score,
    awayScore: state.awayScore,
    isSubmitting: state.isSubmitting,
    errorMessage: state.errorMessage,
    isInitialLoading: state.isInitialLoading,
  );

  void setAwayScore(int? score) => state = GameResultState(
    homeScore: state.homeScore,
    awayScore: score,
    isSubmitting: state.isSubmitting,
    errorMessage: state.errorMessage,
    isInitialLoading: state.isInitialLoading,
  );

  Future<void> submit() async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      await ref
          .read(gameRepositoryProvider)
          .reportGameResult(
            gameId: gameId, // gameId er tilgængelig som parameter til build
            homeScore: state.homeScore,
            awayScore: state.awayScore,
          );

      // 2. Invalidér listen over kampe i den aktive sæson
      final seasonId = ref.read(currentSeasonProvider)?.id;
      if (seasonId != null) {
        ref.invalidate(gamesProvider(seasonId));
      }
      ref.invalidate(gameProvider(gameId));
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  /// Rydder et allerede indberettet resultat, så kampen igen står uden
  /// resultat (i stedet for fx 0-0).
  Future<void> clearResult() async {
    state = GameResultState(
      homeScore: null,
      awayScore: null,
      isSubmitting: state.isSubmitting,
      errorMessage: null,
      isInitialLoading: state.isInitialLoading,
    );
    await submit();
  }
}
