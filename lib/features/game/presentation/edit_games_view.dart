import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:science_cup_app/features/game/application/games_notifier.dart';
import 'package:science_cup_app/features/game/data/enums/game_enums.dart';
import 'package:science_cup_app/features/game/data/models/game_summary.dart';
import 'package:science_cup_app/features/game/presentation/add_edit_game_modal.dart';
import 'package:science_cup_app/features/game/presentation/display_game.dart';
import 'package:science_cup_app/features/game/presentation/games_view.dart';
import 'package:science_cup_app/features/group/data/models/group_ref.dart';
import 'package:science_cup_app/features/season/application/active_season/current_season_provider.dart';
import 'package:science_cup_app/features/team/data/models/team_ref.dart';
import 'package:science_cup_app/shared/presentation/modals/show_create_entity_modal_bottom_sheet.dart';

class EditGamesView extends ConsumerStatefulWidget {
  const EditGamesView({super.key});

  @override
  ConsumerState<EditGamesView> createState() => _EditGamesViewState();
}

class _EditGamesViewState extends ConsumerState<EditGamesView> {
  TeamRef? _teamFilter;
  GroupRef? _groupFilter;
  DateTime? _dateFilter;
  GameStageType? _stageFilter;

  @override
  Widget build(BuildContext context) {
    final currentSeasonId = ref.watch(currentSeasonProvider)?.id;
    if (currentSeasonId == null) {
      return const Center(child: Text("Ingen aktiv sæson valgt"));
    }

    final gamesState = ref.watch(gamesProvider(currentSeasonId));

    return gamesState.when(
      data: (List<GameSummary> games) {
        if (games.isEmpty) {
          return const Center(child: Text("Ingen kampe fundet"));
        }

        final teams = distinctTeams(games);
        final groups = distinctGroups(games);
        final dates = distinctGameDates(games);

        // Nulstil filtre, der ikke længere matcher noget i det hentede data
        // (fx efter sæsonskift eller hvis en kamp er blevet slettet/flyttet).
        if (_teamFilter != null && !teams.any((t) => t.id == _teamFilter!.id)) {
          _teamFilter = null;
        }
        if (_groupFilter != null &&
            !groups.any((g) => g.id == _groupFilter!.id)) {
          _groupFilter = null;
        }
        if (_dateFilter != null &&
            !dates.any((d) => isSameDate(d, _dateFilter!))) {
          _dateFilter = null;
        }

        final placeholders = knockoutPlaceholders(games);

        final filteredGames = games.where((game) {
          if (_stageFilter != null && game.gameStageType != _stageFilter) {
            return false;
          }
          if (_teamFilter != null &&
              game.homeTeam?.id != _teamFilter!.id &&
              game.awayTeam?.id != _teamFilter!.id) {
            return false;
          }
          if (_groupFilter != null && game.group?.id != _groupFilter!.id) {
            return false;
          }
          if (_dateFilter != null &&
              (game.startDate == null ||
                  !isSameDate(game.startDate!, _dateFilter!))) {
            return false;
          }
          return true;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton.icon(
              onPressed: () {
                showCreateEntityModalBottomSheet(
                  context: context,
                  builder: (context) {
                    return AddEditGameModal();
                  },
                );
              },
              label: Text("Tilføj kamp"),
              icon: Icon(Icons.add),
            ),
            const SizedBox(height: 12.0),
            GameFilters(
              teams: teams,
              groups: groups,
              dates: dates,
              selectedTeam: _teamFilter,
              selectedGroup: _groupFilter,
              selectedDate: _dateFilter,
              selectedStageType: _stageFilter,
              onTeamChanged: (team) => setState(() => _teamFilter = team),
              onGroupChanged: (group) => setState(() => _groupFilter = group),
              onDateChanged: (date) => setState(() => _dateFilter = date),
              onStageTypeChanged: (stage) =>
                  setState(() => _stageFilter = stage),
              onClearAll: () => setState(() {
                _teamFilter = null;
                _groupFilter = null;
                _dateFilter = null;
                _stageFilter = null;
              }),
            ),
            const SizedBox(height: 8.0),
            if (filteredGames.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text("Ingen kampe matcher de valgte filtre"),
                ),
              )
            else
              ...filteredGames.map((game) {
                return DisplayGame(
                  game: game,
                  homePlaceholder: placeholders[game.id]?[GameSlot.home],
                  awayPlaceholder: placeholders[game.id]?[GameSlot.away],
                );
              }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text("Fejl: $error")),
    );
  }
}
