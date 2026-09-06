// lib/features/standings/presentation/screens/all_standings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:science_cup_app/features/season/application/active_season/current_season_provider.dart';
import 'package:science_cup_app/features/standings/application/all_group_standings_provider.dart';
import 'package:science_cup_app/features/standings/data/group_standings.dart';
import 'package:science_cup_app/features/standings/data/standing_row.dart';
import 'package:science_cup_app/features/team/presentation/team_icon.dart';

class AllStandingsView extends ConsumerWidget {
  const AllStandingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonId = ref.watch(currentSeasonProvider)?.id;
    if (seasonId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final allStandingsAsync = ref.watch(allGroupStandingsProvider(seasonId));

    return allStandingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fejl: $e')),
      data: (allStandings) => Column(
        children: [
          for (final groupStandings in allStandings)
            _GroupStandingsCard(groupStandings),
        ],
      ),
    );
  }
}

class _GroupStandingsCard extends StatelessWidget {
  final GroupStandings groupStandings;
  const _GroupStandingsCard(this.groupStandings);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 10.0),
            child: Text(
              groupStandings.group.name ?? 'Ukendt gruppe',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (groupStandings.standings.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 20.0),
              child: Text(
                'Ingen kampe spillet endnu',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            _StandingsTable(groupStandings.standings),
        ],
      ),
    );
  }
}

class _StandingsTable extends StatelessWidget {
  final List<StandingRow> standings;
  const _StandingsTable(this.standings);

  static const _numberColumnWidth = FixedColumnWidth(28.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const {
          0: _numberColumnWidth,
          1: FixedColumnWidth(168.0),
          2: _numberColumnWidth,
          3: _numberColumnWidth,
          4: _numberColumnWidth,
          5: _numberColumnWidth,
          6: FixedColumnWidth(48.0),
          7: FixedColumnWidth(48.0),
          8: FixedColumnWidth(48.0),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
            ),
            children: [
              _headerCell('#', headerStyle),
              _headerCell('Hold', headerStyle, alignLeft: true),
              _headerCell('K', headerStyle),
              _headerCell('V', headerStyle),
              _headerCell('U', headerStyle),
              _headerCell('T', headerStyle),
              _headerCell('Mål', headerStyle),
              _headerCell('+/-', headerStyle),
              _headerCell('P', headerStyle),
            ],
          ),
          for (final entry in standings.asMap().entries)
            _buildRow(context, entry.key, entry.value),
        ],
      ),
    );
  }

  TableRow _buildRow(BuildContext context, int index, StandingRow row) {
    final theme = Theme.of(context);
    final position = index + 1;
    final isOddRow = index.isOdd;

    final diffColor = row.goalDifference > 0
        ? theme.colorScheme.primary
        : row.goalDifference < 0
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    final diffLabel = row.goalDifference > 0
        ? '+${row.goalDifference}'
        : '${row.goalDifference}';

    return TableRow(
      decoration: BoxDecoration(
        color: isOddRow
            ? theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5)
            : null,
      ),
      children: [
        _cell(
          Center(
            child: Text(
              '$position',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: position == 1 ? FontWeight.bold : null,
              ),
            ),
          ),
        ),
        _cell(
          Row(
            children: [
              TeamIcon(teamName: row.teamName, size: 24.0),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  row.teamName,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        _numberCell('${row.played}', theme),
        _numberCell('${row.wins}', theme),
        _numberCell('${row.draws}', theme),
        _numberCell('${row.losses}', theme),
        _numberCell('${row.goalsFor}-${row.goalsAgainst}', theme),
        _numberCell(diffLabel, theme, color: diffColor),
        _cell(
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 3.0,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                '${row.points}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _headerCell(
    String label,
    TextStyle? style, {
    bool alignLeft = false,
  }) {
    return _cell(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Align(
          alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
          child: Text(label, style: style),
        ),
      ),
    );
  }

  static Widget _numberCell(String label, ThemeData theme, {Color? color}) {
    return _cell(
      Center(
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: color),
        ),
      ),
    );
  }

  static Widget _cell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
      child: child,
    );
  }
}
