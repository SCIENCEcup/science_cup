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
      await _supabase
          .from('games')
          .update({
            'home_score': homeScore,
            'away_score': awayScore,
            'status':
                'completed', // Assuming you want to mark the game as completed
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
