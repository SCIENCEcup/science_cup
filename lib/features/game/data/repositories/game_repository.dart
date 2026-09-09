import 'package:science_cup_app/features/game/data/enums/game_enums.dart';
import 'package:science_cup_app/features/game/data/models/game.dart';
import 'package:science_cup_app/features/game/data/models/game_summary.dart';
import 'package:science_cup_app/features/game/data/models/write_game_request.dart';
import 'package:supabase/supabase.dart';

class GameRepository {
  final SupabaseClient _supabase;

  GameRepository({required SupabaseClient supabase}) : _supabase = supabase;

  Future<Game> getGame(int gameId) async {
    final response = await _supabase
        .from('games')
        .select('''
        id,
        status,
        home_score,
        away_score,
        start_date,
        round_number,
        next_game_id,
        next_game_slot,

        home_team:home_team_id(id, name),
        away_team:away_team_id(id, name),
        referee_team:referee_team_id(id, name),
        group:group_id(id, name)
      ''')
        .eq('id', gameId)
        .single();

    return Game.fromJson(response);
  }

  Future<List<GameSummary>> getGamesForSeason(int seasonId) async {
    final response = await _supabase
        .from('games')
        .select('''
        id,
        status,
        home_score,
        away_score,
        start_date,
        round_number,
        next_game_id,
        next_game_slot,

        home_team:home_team_id(id, name),
        away_team:away_team_id(id, name),
        referee_team:referee_team_id(id, name),
        group:group_id(id, name)
      ''')
        .eq('season_id', seasonId)
        .order('start_date', ascending: true);

    return (response as List<dynamic>)
        .map((gameJson) => GameSummary.fromJson(gameJson))
        .toList();
  }

  /// Opretter en ny kamp
  Future<Game> createGame(WriteGameRequest request) async {
    try {
      final response = await _supabase
          .from('games')
          .insert(request.toJson())
          .select()
          .single();

      return Game.fromJson(response);
    } catch (e) {
      throw Exception('Kunne ikke oprette kamp: $e');
    }
  }

  /// Opdaterer en eksisterende kamp
  Future<Game> updateGame(WriteGameRequest request) async {
    if (request.id == null) {
      throw Exception('Game ID er påkrævet for at opdatere.');
    }
    try {
      final response = await _supabase
          .from('games')
          .update(request.toJson())
          .eq('id', request.id!)
          .select()
          .single();

      return Game.fromJson(response);
    } catch (e) {
      throw Exception('Kunne ikke opdatere kamp: $e');
    }
  }

  /// Opretter et helt slutspil (single-elimination) for sæsonen ud fra
  /// [roundCount] runder (1 = kun en finale, 2 = semifinale + finale, osv.).
  ///
  /// Kampene oprettes ét niveau ad gangen, startende med finalen (round 0),
  /// da hver runde skal kende ID'et på den kamp, vinderen går videre til
  /// (`next_game_id`). Kampene i den sidste (tidligste) runde er dem, admin
  /// efterfølgende sætter hold på; resten udfyldes automatisk, efterhånden
  /// som resultater indberettes.
  Future<List<Game>> createPlayoffBracket({
    required int seasonId,
    required int roundCount,
  }) async {
    if (roundCount < 1) {
      throw Exception('Et slutspil skal have mindst 1 runde.');
    }

    final allGames = <Game>[];
    List<Game> previousRoundGames = [];

    for (var round = 0; round < roundCount; round++) {
      final gamesInRound = 1 << round; // 2^round
      final currentRoundGames = <Game>[];

      for (var i = 0; i < gamesInRound; i++) {
        int? nextGameId;
        GameSlot? nextGameSlot;
        if (round > 0) {
          final parent = previousRoundGames[i ~/ 2];
          nextGameId = parent.id;
          nextGameSlot = i.isEven ? GameSlot.home : GameSlot.away;
        }

        final created = await createGame(
          WriteGameRequest(
            seasonId: seasonId,
            roundNumber: round,
            nextGameId: nextGameId,
            nextGameSlot: nextGameSlot,
          ),
        );
        currentRoundGames.add(created);
        allGames.add(created);
      }

      previousRoundGames = currentRoundGames;
    }

    return allGames;
  }

  /// Sætter det vindende hold i den kamp, en slutspilskamp peger videre
  /// til (`next_game_id`/`next_game_slot`), så bracket'et automatisk
  /// bygges videre, efterhånden som resultater indberettes.
  Future<void> advanceWinner({
    required int nextGameId,
    required GameSlot slot,
    required int teamId,
  }) async {
    try {
      final column = slot == GameSlot.home ? 'home_team_id' : 'away_team_id';
      await _supabase
          .from('games')
          .update({column: teamId})
          .eq('id', nextGameId);
    } catch (e) {
      throw Exception('Kunne ikke fremrykke vinderhold: $e');
    }
  }

  Future<void> deleteGame(int id) async {
    try {
      await _supabase.from('games').delete().eq('id', id);
    } catch (e) {
      throw Exception('Kunne ikke slette kamp: $e');
    }
  }

  Future<void> reportGameResult({
    required int gameId,
    required int? homeScore,
    required int? awayScore,
  }) async {
    try {
      final hasResult = homeScore != null && awayScore != null;
      await _supabase
          .from('games')
          .update({
            'home_score': homeScore,
            'away_score': awayScore,
            // Hvis resultatet ryddes (begge scorer sat til null igen),
            // skal kampen ikke længere fremstå som afsluttet.
            'status': hasResult ? 'completed' : 'ready',
          })
          .eq('id', gameId);
    } catch (e) {
      throw Exception('Kunne ikke indberette resultat: $e');
    }
  }

  Future<List<Game>> getGamesForGroup(int groupId) async {
    final response = await _supabase
        .from('games')
        .select('''
        id,
        status,
        home_score,
        away_score,
        start_date,
        round_number,

        home_team:home_team_id(id, name),
        away_team:away_team_id(id, name),
        referee_team:referee_team_id(id, name),
        group:group_id(id, name)
      ''')
        .eq('group_id', groupId)
        .order('start_date', ascending: true);

    return (response as List<dynamic>)
        .map((gameJson) => Game.fromJson(gameJson))
        .toList();
  }
}
