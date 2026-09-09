import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:science_cup_app/features/game/application/games_notifier.dart';
import 'package:science_cup_app/features/game/data/enums/game_enums.dart';
import 'package:science_cup_app/features/game/data/models/game_summary.dart';
import 'package:science_cup_app/features/game/presentation/display_game.dart';
import 'package:science_cup_app/features/group/data/models/group_ref.dart';
import 'package:science_cup_app/features/season/application/active_season/current_season_provider.dart';
import 'package:science_cup_app/features/team/data/models/team_ref.dart';

class GamesView extends ConsumerStatefulWidget {
  const GamesView({
    super.key,
    required this.showAllGames,
    required this.selectedDate,
    required this.onDateChanged,
  });

  /// Styres udefra (sæsonsidens app bar-knap). Når true vises alle kampe i
  /// sæsonen (kun hold-/gruppefiltre er relevante); når false vises kun
  /// kampene for [selectedDate] (styret af datovælgeren i app-barens bund).
  final bool showAllGames;
  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onDateChanged;

  @override
  ConsumerState<GamesView> createState() => _GamesViewState();
}

class _GamesViewState extends ConsumerState<GamesView> {
  TeamRef? _teamFilter;
  GroupRef? _groupFilter;

  @override
  void didUpdateWidget(covariant GamesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Hold-/gruppefiltre er kun relevante i "alle kampe"-visningen, så de
    // ryddes, når man forlader den — ellers ville de ligge og filtrere i
    // baggrunden, næste gang man slår dem til igen.
    if (oldWidget.showAllGames && !widget.showAllGames) {
      _teamFilter = null;
      _groupFilter = null;
    }
  }

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

        // Nulstil hold-/gruppefiltre, der ikke længere matcher noget i det
        // hentede data (fx efter sæsonskift eller hvis en kamp er blevet
        // slettet/flyttet).
        if (_teamFilter != null && !teams.any((t) => t.id == _teamFilter!.id)) {
          _teamFilter = null;
        }
        if (_groupFilter != null &&
            !groups.any((g) => g.id == _groupFilter!.id)) {
          _groupFilter = null;
        }

        final placeholders = knockoutPlaceholders(games);

        final filteredGames = games.where((game) {
          if (widget.showAllGames) {
            if (_teamFilter != null &&
                game.homeTeam?.id != _teamFilter!.id &&
                game.awayTeam?.id != _teamFilter!.id) {
              return false;
            }
            if (_groupFilter != null && game.group?.id != _groupFilter!.id) {
              return false;
            }
            return true;
          }
          return widget.selectedDate != null &&
              game.startDate != null &&
              _isSameDate(game.startDate!, widget.selectedDate!);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showAllGames)
              _GameFilters(
                teams: teams,
                groups: groups,
                selectedTeam: _teamFilter,
                selectedGroup: _groupFilter,
                onTeamChanged: (team) => setState(() => _teamFilter = team),
                onGroupChanged: (group) => setState(() => _groupFilter = group),
                onClearAll: () => setState(() {
                  _teamFilter = null;
                  _groupFilter = null;
                }),
              ),
            const SizedBox(height: 8.0),
            if (filteredGames.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(child: Text(_emptyStateMessage())),
              )
            else
              ...filteredGames.map(
                (game) => DisplayGame(
                  game: game,
                  homePlaceholder: placeholders[game.id]?[GameSlot.home],
                  awayPlaceholder: placeholders[game.id]?[GameSlot.away],
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text("Fejl: $error")),
    );
  }

  String _emptyStateMessage() {
    if (!widget.showAllGames) return "Ingen kampe denne dag";
    final hasActiveFilter = _teamFilter != null || _groupFilter != null;
    if (hasActiveFilter) return "Ingen kampe matcher de valgte filtre";
    return "Ingen kampe fundet";
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
}

List<DateTime> _distinctGameDates(List<GameSummary> games) {
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

/// For hver slutspilskamp med et ledigt hjemme-/udehold, som en tidligere
/// kamp i bracket'et peger videre til (`next_game_id`/`next_game_slot`),
/// dannes en kort label om hvem der kommer til at stå på pladsen, fx
/// "Vinder af kvartfinale" — så man kan se bracket'ets struktur, selvom
/// de tidligere kampe ikke er spillet endnu.
Map<int, Map<GameSlot, String>> knockoutPlaceholders(List<GameSummary> games) {
  final placeholders = <int, Map<GameSlot, String>>{};
  for (final feeder in games) {
    final nextGameId = feeder.nextGameId;
    final nextGameSlot = feeder.nextGameSlot;
    if (nextGameId == null || nextGameSlot == null) continue;

    final stage = knockoutStageName(feeder.roundNumber ?? 0).toLowerCase();
    placeholders.putIfAbsent(nextGameId, () => {})[nextGameSlot] =
        "Vinder af $stage";
  }
  return placeholders;
}

class _GameFilters extends StatelessWidget {
  const _GameFilters({
    required this.teams,
    required this.groups,
    required this.selectedTeam,
    required this.selectedGroup,
    required this.onTeamChanged,
    required this.onGroupChanged,
    required this.onClearAll,
  });

  final List<TeamRef> teams;
  final List<GroupRef> groups;

  final TeamRef? selectedTeam;
  final GroupRef? selectedGroup;

  final ValueChanged<TeamRef?> onTeamChanged;
  final ValueChanged<GroupRef?> onGroupChanged;
  final VoidCallback onClearAll;

  bool get _hasActiveFilter => selectedTeam != null || selectedGroup != null;

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
}

/// Horisontal datovælger til app-barens `bottom:`, der viser de datoer hvor
/// sæsonen faktisk har kampe — plus dagens dato som fast anker, selvom den
/// ikke selv har kampe — ligesom "fixtures"-kalenderen i andre fodboldapps
/// (Flashscore, OneFootball m.fl.). Tidligere datoer ligger til venstre,
/// kommende til højre, og stripet centreres automatisk omkring den valgte
/// (eller aktuelle) dato, så begge retninger er lette at nå.
class GameDateBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  const GameDateBar({
    super.key,
    required this.seasonId,
    required this.selectedDate,
    required this.onDateChanged,
  });

  final int seasonId;
  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onDateChanged;

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  ConsumerState<GameDateBar> createState() => _GameDateBarState();
}

class _GameDateBarState extends ConsumerState<GameDateBar> {
  final Map<DateTime, GlobalKey> _chipKeys = {};
  bool _hasCenteredInitially = false;

  @override
  void didUpdateWidget(covariant GameDateBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seasonId != widget.seasonId) {
      _hasCenteredInitially = false;
      _chipKeys.clear();
    }
  }

  GlobalKey _keyFor(DateTime date) =>
      _chipKeys.putIfAbsent(date, () => GlobalKey());

  void _centerOn(DateTime? date, {bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Slås op først når frame'et er bygget (ikke ved kald-tidspunktet) —
      // ellers er chip'en for den valgte dato ofte ikke nået at blive
      // bygget af ListView'et endnu, og nøglen findes derfor ikke.
      final key = date == null ? null : _chipKeys[date];
      final chipContext = key?.currentContext;
      if (chipContext == null) return;
      Scrollable.ensureVisible(
        chipContext,
        alignment: 0.5,
        duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final gamesAsync = ref.watch(gamesProvider(widget.seasonId));

    if (gamesAsync.isLoading && !gamesAsync.hasValue) {
      return SizedBox(height: widget.preferredSize.height);
    }
    if (gamesAsync.hasError) {
      return SizedBox(height: widget.preferredSize.height);
    }

    final dates = _distinctGameDates(gamesAsync.value ?? const []);

    // Dagens dato er altid med som anker i stripet, selvom der ikke er
    // kampe i dag — så kan man altid se, hvor "i dag" ligger, og nemt
    // finde frem til den seneste dag med kampe (til venstre) eller den
    // næste dag med kampe (til højre).
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (!dates.any((d) => _isSameDate(d, today))) {
      dates.add(today);
      dates.sort();
    }

    if (!_hasCenteredInitially) {
      _hasCenteredInitially = true;
      _centerOn(widget.selectedDate ?? today);
    }

    return SizedBox(
      height: widget.preferredSize.height,
      child: ListView.separated(
        // Bygger alle chips med det samme (i stedet for kun dem der er
        // synlige), så Scrollable.ensureVisible kan finde og centrere en
        // chip, selvom den ligger langt uden for det oprindelige view.
        cacheExtent: 4000.0,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        itemCount: dates.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8.0),
        itemBuilder: (context, index) {
          final date = dates[index];
          final selected =
              widget.selectedDate != null &&
              _isSameDate(date, widget.selectedDate!);
          return _DateChip(
            key: _keyFor(date),
            label: _dateChipLabel(date),
            selected: selected,
            isToday: _isSameDate(date, today),
            onTap: () {
              widget.onDateChanged(date);
              _centerOn(date, animate: true);
            },
          );
        },
      ),
    );
  }
}

String _dateChipLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final tomorrow = today.add(const Duration(days: 1));

  if (_isSameDate(date, today)) return "I dag";
  if (_isSameDate(date, tomorrow)) return "I morgen";
  if (_isSameDate(date, yesterday)) return "I går";

  final weekday = DateFormat('EEE', 'da_DK').format(date);
  final dayMonth = DateFormat('d. MMM', 'da_DK').format(date);
  return "$weekday $dayMonth";
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    super.key,
    required this.label,
    required this.selected,
    this.isToday = false,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = selected
        ? theme.colorScheme.primaryContainer
        : Colors.transparent;
    final borderColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    final foreground = selected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;
    final borderWidth = selected ? 1.5 : 1.0;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.0),
            // "I dag" får altid en fremhævet underkant, uanset om dagen er
            // valgt eller ej, så man hurtigt kan se, hvor "i dag" ligger i
            // stripet.
            border: Border(
              top: BorderSide(color: borderColor, width: borderWidth),
              left: BorderSide(color: borderColor, width: borderWidth),
              right: BorderSide(color: borderColor, width: borderWidth),
              bottom: BorderSide(
                color: isToday ? theme.colorScheme.primary : borderColor,
                width: isToday ? 3.0 : borderWidth,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
