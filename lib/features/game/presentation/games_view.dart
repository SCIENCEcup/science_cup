import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:science_cup_app/features/game/application/games_notifier.dart';
import 'package:science_cup_app/features/game/data/models/game_summary.dart';
import 'package:science_cup_app/features/game/presentation/display_game.dart';
import 'package:science_cup_app/features/group/data/models/group_ref.dart';
import 'package:science_cup_app/features/season/application/active_season/current_season_provider.dart';
import 'package:science_cup_app/features/team/data/models/team_ref.dart';

class GamesView extends ConsumerStatefulWidget {
  const GamesView({super.key});

  @override
  ConsumerState<GamesView> createState() => _GamesViewState();
}

class _GamesViewState extends ConsumerState<GamesView> {
  TeamRef? _teamFilter;
  GroupRef? _groupFilter;
  DateTime? _dateFilter;

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

        final teams = _distinctTeams(games);
        final groups = _distinctGroups(games);
        final gameDates = _distinctDates(games);

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
            !gameDates.any((d) => _isSameDate(d, _dateFilter!))) {
          _dateFilter = null;
        }

        final filteredGames = games.where((game) {
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
                  !_isSameDate(game.startDate!, _dateFilter!))) {
            return false;
          }
          return true;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GameFilters(
              teams: teams,
              groups: groups,
              gameDates: gameDates,
              selectedTeam: _teamFilter,
              selectedGroup: _groupFilter,
              selectedDate: _dateFilter,
              onTeamChanged: (team) => setState(() => _teamFilter = team),
              onGroupChanged: (group) => setState(() => _groupFilter = group),
              onDateChanged: (date) => setState(() => _dateFilter = date),
              onClearAll: () => setState(() {
                _teamFilter = null;
                _groupFilter = null;
                _dateFilter = null;
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
              ...filteredGames.map((game) => DisplayGame(game: game)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text("Fejl: $error")),
    );
  }

  List<TeamRef> _distinctTeams(List<GameSummary> games) {
    final byId = <int, TeamRef>{};
    for (final game in games) {
      if (game.homeTeam != null) byId[game.homeTeam!.id] = game.homeTeam!;
      if (game.awayTeam != null) byId[game.awayTeam!.id] = game.awayTeam!;
    }
    final teams = byId.values.toList()
      ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
    return teams;
  }

  List<GroupRef> _distinctGroups(List<GameSummary> games) {
    final byId = <int, GroupRef>{};
    for (final game in games) {
      if (game.group != null) byId[game.group!.id] = game.group!;
    }
    final groups = byId.values.toList()
      ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
    return groups;
  }

  List<DateTime> _distinctDates(List<GameSummary> games) {
    final dates = <DateTime>{};
    for (final game in games) {
      final start = game.startDate;
      if (start != null) {
        dates.add(DateTime(start.year, start.month, start.day));
      }
    }
    return dates.toList()..sort();
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _GameFilters extends StatelessWidget {
  const _GameFilters({
    required this.teams,
    required this.groups,
    required this.gameDates,
    required this.selectedTeam,
    required this.selectedGroup,
    required this.selectedDate,
    required this.onTeamChanged,
    required this.onGroupChanged,
    required this.onDateChanged,
    required this.onClearAll,
  });

  final List<TeamRef> teams;
  final List<GroupRef> groups;
  final List<DateTime> gameDates;

  final TeamRef? selectedTeam;
  final GroupRef? selectedGroup;
  final DateTime? selectedDate;

  final ValueChanged<TeamRef?> onTeamChanged;
  final ValueChanged<GroupRef?> onGroupChanged;
  final ValueChanged<DateTime?> onDateChanged;
  final VoidCallback onClearAll;

  bool get _hasActiveFilter =>
      selectedTeam != null || selectedGroup != null || selectedDate != null;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildDropdown<TeamRef>(
          context: context,
          hint: "Alle hold",
          value: selectedTeam,
          items: teams,
          itemLabel: (team) => team.name ?? "Ukendt hold",
          onChanged: onTeamChanged,
        ),
        _buildDropdown<GroupRef>(
          context: context,
          hint: "Alle grupper",
          value: selectedGroup,
          items: groups,
          itemLabel: (group) => group.name ?? "Ukendt gruppe",
          onChanged: onGroupChanged,
        ),
        if (gameDates.isNotEmpty) _buildDateFilter(context),
        if (_hasActiveFilter)
          ActionChip(
            avatar: const Icon(Icons.filter_alt_off, size: 18.0),
            label: const Text("Ryd filtre"),
            onPressed: onClearAll,
          ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required BuildContext context,
    required String hint,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          hint: Text(hint, style: theme.textTheme.bodyMedium),
          icon: const Icon(Icons.expand_more, size: 18.0),
          borderRadius: BorderRadius.circular(12.0),
          items: [
            DropdownMenuItem<T?>(value: null, child: Text(hint)),
            ...items.map(
              (item) => DropdownMenuItem<T?>(
                value: item,
                child: Text(itemLabel(item)),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDateFilter(BuildContext context) {
    final label = selectedDate == null
        ? "Alle datoer"
        : DateFormat('d. MMM', 'da_DK').format(selectedDate!);

    return InputChip(
      avatar: const Icon(Icons.event, size: 18.0),
      label: Text(label),
      onPressed: () async {
        final firstDate = gameDates.first;
        final lastDate = gameDates.last;
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? firstDate,
          firstDate: firstDate,
          lastDate: lastDate,
          helpText: "Vælg dato",
          cancelText: "Annuller",
          confirmText: "Vælg",
          selectableDayPredicate: (day) => gameDates.any(
            (d) =>
                d.year == day.year && d.month == day.month && d.day == day.day,
          ),
        );
        if (picked != null) {
          onDateChanged(picked);
        }
      },
      onDeleted: selectedDate != null ? () => onDateChanged(null) : null,
      deleteIcon: const Icon(Icons.close, size: 16.0),
    );
  }
}
