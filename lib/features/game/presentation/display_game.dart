import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:science_cup_app/features/game/data/enums/game_enums.dart';
import 'package:science_cup_app/features/game/data/models/game_summary.dart';
import 'package:science_cup_app/features/game/presentation/add_game_score_modal.dart';
import 'package:science_cup_app/features/permissions/application/user_permissions_notifier.dart';
import 'package:science_cup_app/features/team/presentation/team_icon.dart';
import 'package:science_cup_app/shared/presentation/modals/show_create_entity_modal_bottom_sheet.dart';

class DisplayGame extends ConsumerWidget {
  const DisplayGame({super.key, required this.game});

  final GameSummary game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userPermissions = ref.watch(userPermissionsProvider).value;
    final canReport =
        game.homeTeam?.id != null &&
        userPermissions?.canReportResults(game.homeTeam!.id) == true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 10.0),
        child: Column(
          children: [
            _GameInfoRow(game: game),
            const SizedBox(height: 10.0),
            _GameScoreRow(game: game),
            if (game.refereeTeam?.name != null) ...[
              const SizedBox(height: 8.0),
              _RefereeRow(refereeTeamName: game.refereeTeam!.name!),
            ],
            if (canReport) ...[
              const SizedBox(height: 8.0),
              const Divider(height: 1),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    showCreateEntityModalBottomSheet(
                      context: context,
                      builder: (context) => AddGameResultModal(game: game),
                    );
                  },
                  icon: const Icon(Icons.assignment_add, size: 18.0),
                  label: const Text("Indberet resultat"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GameInfoRow extends StatelessWidget {
  const _GameInfoRow({required this.game});

  final GameSummary game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final infoParts = <String>[
      if (game.group?.name != null) game.group!.name!,
      if (game.roundNumber != null) "Runde ${game.roundNumber}",
    ];

    return Row(
      children: [
        Expanded(
          child: Text(
            infoParts.join(" · "),
            style: mutedStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (game.startDate != null) ...[
          Text(_formatDate(game.startDate!), style: mutedStyle),
          const SizedBox(width: 8.0),
        ],
        _StatusBadge(status: game.status),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    return DateFormat('d. MMM HH:mm', 'da_DK').format(date);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final GameStatus? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      GameStatus.playing => ("LIVE", Colors.red),
      GameStatus.completed => ("Afsluttet", theme.colorScheme.outline),
      GameStatus.ready => ("Klar", theme.colorScheme.primary),
      GameStatus.pending || null => ("Kommer", theme.colorScheme.outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _GameScoreRow extends StatelessWidget {
  const _GameScoreRow({required this.game});

  final GameSummary game;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _TeamColumn(teamName: game.homeTeam?.name)),
        _ScoreBox(game: game),
        Expanded(child: _TeamColumn(teamName: game.awayTeam?.name)),
      ],
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({required this.teamName});

  final String? teamName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TeamIcon(teamName: teamName ?? "?"),
        const SizedBox(height: 6.0),
        Text(
          teamName ?? "Ukendt hold",
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RefereeRow extends StatelessWidget {
  const _RefereeRow({required this.refereeTeamName});

  final String refereeTeamName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sports,
            size: 14.0,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4.0),
          Flexible(
            child: Text(
              "Dommer: $refereeTeamName",
              style: mutedStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({required this.game});

  final GameSummary game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasScore = game.homeScore != null && game.awayScore != null;
    final isLive = game.status == GameStatus.playing;

    Widget content;
    if (hasScore) {
      content = Text(
        "${game.homeScore} - ${game.awayScore}",
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: isLive ? Colors.red : theme.colorScheme.onSurface,
        ),
      );
    } else if (game.startDate != null) {
      content = Text(
        DateFormat('HH:mm').format(game.startDate!),
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    } else {
      content = Text(
        "vs",
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 56.0),
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      alignment: Alignment.center,
      child: content,
    );
  }
}
