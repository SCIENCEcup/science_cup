import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:science_cup_app/features/game/data/enums/game_enums.dart';
import 'package:science_cup_app/features/group/data/models/group_ref.dart';
import 'package:science_cup_app/features/team/data/models/team_ref.dart';

part 'game_summary.freezed.dart';
part 'game_summary.g.dart';

@freezed
abstract class GameSummary with _$GameSummary {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory GameSummary({
    required int id,

    GameStatus? status,

    int? homeScore,
    int? awayScore,

    DateTime? startDate,
    int? roundNumber,

    // Slutspil: hvilken kamp vinderen af denne kamp går videre til.
    int? nextGameId,
    GameSlot? nextGameSlot,

    TeamRef? homeTeam,
    TeamRef? awayTeam,
    TeamRef? refereeTeam,

    GroupRef? group,
  }) = _GameSummary;

  factory GameSummary.fromJson(Map<String, dynamic> json) =>
      _$GameSummaryFromJson(json);
}
