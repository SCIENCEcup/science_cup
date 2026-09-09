import 'package:flutter/material.dart'; // for TimeOfDay
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:science_cup_app/features/game/application/game_repository_provider.dart';
import 'package:science_cup_app/features/game/application/games_notifier.dart';
import 'package:science_cup_app/features/game/data/enums/game_enums.dart';
import 'package:science_cup_app/features/game/data/models/game.dart';
import 'package:science_cup_app/features/game/data/models/write_game_request.dart';

part 'game_form_notifier.g.dart';

/// Sentinel, der lader `copyWith` skelne mellem "feltet blev ikke angivet"
/// og "feltet skal eksplicit ryddes til null" — almindeligt `??`-mønster
/// kan ikke nulstille et felt, fordi `null ?? gammelVærdi` altid bliver
/// den gamle værdi.
class _Undefined {
  const _Undefined();
}

const _undefined = _Undefined();

// State-klassen
class GameFormState {
  final int seasonId;
  final int? id;
  final GameStageType gameStageType;
  final int? groupId;
  final int? homeTeamId;
  final int? awayTeamId;
  final int? refereeTeamId;
  final DateTime? startDate;
  final TimeOfDay? startTime;

  /// Kun relevant, når man opretter et nyt slutspil (dvs. [id] er null og
  /// [gameStageType] er `round`): antal runder i bracket'et (1 = finale,
  /// 2 = semifinale + finale, osv.).
  final int roundCount;

  final bool isSubmitting;
  final String? errorMessage;

  const GameFormState({
    required this.seasonId,
    this.id,
    this.gameStageType = GameStageType.group,
    this.groupId,
    this.homeTeamId,
    this.awayTeamId,
    this.refereeTeamId,
    this.startDate,
    this.startTime,
    this.roundCount = 1,
    this.isSubmitting = false,
    this.errorMessage,
  });

  GameFormState copyWith({
    int? seasonId,
    Object? id = _undefined,
    GameStageType? gameStageType,
    Object? groupId = _undefined,
    Object? homeTeamId = _undefined,
    Object? awayTeamId = _undefined,
    Object? refereeTeamId = _undefined,
    Object? startDate = _undefined,
    Object? startTime = _undefined,
    int? roundCount,
    bool? isSubmitting,
    Object? errorMessage = _undefined,
  }) {
    return GameFormState(
      seasonId: seasonId ?? this.seasonId,
      id: identical(id, _undefined) ? this.id : id as int?,
      gameStageType: gameStageType ?? this.gameStageType,
      groupId: identical(groupId, _undefined)
          ? this.groupId
          : groupId as int?,
      homeTeamId: identical(homeTeamId, _undefined)
          ? this.homeTeamId
          : homeTeamId as int?,
      awayTeamId: identical(awayTeamId, _undefined)
          ? this.awayTeamId
          : awayTeamId as int?,
      refereeTeamId: identical(refereeTeamId, _undefined)
          ? this.refereeTeamId
          : refereeTeamId as int?,
      startDate: identical(startDate, _undefined)
          ? this.startDate
          : startDate as DateTime?,
      startTime: identical(startTime, _undefined)
          ? this.startTime
          : startTime as TimeOfDay?,
      roundCount: roundCount ?? this.roundCount,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: identical(errorMessage, _undefined)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

@riverpod
class GameFormNotifier extends _$GameFormNotifier {
  @override
  GameFormState build((int, Game?) args) {
    final seasonId = args.$1;
    final game = args.$2;

    return GameFormState(
      seasonId: seasonId,
      id: game?.id,
      gameStageType: game?.gameStageType ?? GameStageType.group,
      groupId: game?.group?.id,
      homeTeamId: game?.homeTeam?.id,
      awayTeamId: game?.awayTeam?.id,
      refereeTeamId: game?.refereeTeam?.id,
      startDate: game?.startDate,
      startTime: game?.startDate != null
          ? TimeOfDay.fromDateTime(game!.startDate!)
          : null,
    );
  }

  // Metoder til UI
  void setGameStageType(GameStageType type) =>
      state = state.copyWith(gameStageType: type);

  void setGroupId(int? groupId) => state = state.copyWith(
    groupId: groupId,
    homeTeamId: null,
    awayTeamId: null,
  );

  void setHomeTeamId(int? teamId) =>
      state = state.copyWith(homeTeamId: teamId);

  void setAwayTeamId(int? teamId) =>
      state = state.copyWith(awayTeamId: teamId);

  void setRefereeTeamId(int? teamId) =>
      state = state.copyWith(refereeTeamId: teamId);

  void setStartDate(DateTime? date) => state = state.copyWith(startDate: date);

  void setStartTime(TimeOfDay? time) => state = state.copyWith(startTime: time);

  void setRoundCount(int count) => state = state.copyWith(roundCount: count);

  Future<void> submit() async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    DateTime? startDateTime;
    if (state.startDate != null && state.startTime != null) {
      startDateTime = DateTime(
        state.startDate!.year,
        state.startDate!.month,
        state.startDate!.day,
        state.startTime!.hour,
        state.startTime!.minute,
      );
    } else if (state.startDate != null) {
      startDateTime = state.startDate;
    }

    final request = WriteGameRequest(
      id: state.id,
      seasonId: state.seasonId,
      groupId: state.groupId,
      homeTeamId: state.homeTeamId,
      awayTeamId: state.awayTeamId,
      refereeTeamId: state.refereeTeamId,
      startDate: startDateTime,
    );

    try {
      final repo = ref.read(gameRepositoryProvider);
      if (request.id == null) {
        await repo.createGame(request);
      } else {
        await repo.updateGame(request);
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isSubmitting: false);
      return;
    }

    state = state.copyWith(isSubmitting: false);
    ref.invalidate(gamesProvider(state.seasonId));
  }

  /// Opretter et helt nyt slutspil (bracket) ud fra [GameFormState.roundCount]
  /// i stedet for én enkelt kamp. Kun relevant når man opretter (ikke
  /// redigerer) og har valgt slutspil som kamptype.
  Future<void> submitPlayoffBracket() async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final repo = ref.read(gameRepositoryProvider);
      await repo.createPlayoffBracket(
        seasonId: state.seasonId,
        roundCount: state.roundCount,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isSubmitting: false);
      return;
    }

    state = state.copyWith(isSubmitting: false);
    ref.invalidate(gamesProvider(state.seasonId));
  }
}
