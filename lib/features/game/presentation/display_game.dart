import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:science_cup_app/features/game/application/game_provider.dart';
import 'package:science_cup_app/features/game/application/games_notifier.dart';
import 'package:science_cup_app/features/game/data/enums/game_enums.dart';
import 'package:science_cup_app/features/game/data/models/game_summary.dart';
import 'package:science_cup_app/features/game/presentation/add_edit_game_modal.dart';
import 'package:science_cup_app/features/game/presentation/add_game_score_modal.dart';
import 'package:science_cup_app/features/group/application/group_notifier.dart';
import 'package:science_cup_app/features/permissions/application/user_permissions_notifier.dart';
import 'package:science_cup_app/features/season/application/active_season/current_season_provider.dart';
import 'package:science_cup_app/features/team/application/team_providers.dart';
import 'package:science_cup_app/features/team/presentation/team_icon.dart';
import 'package:science_cup_app/shared/presentation/modals/show_create_entity_modal_bottom_sheet.dart';
import 'package:science_cup_app/shared/presentation/widgets/confirmation_dialog/confirmation_fields.dart';
import 'package:science_cup_app/shared/presentation/widgets/edit_delete_menu.dart';

class DisplayGame extends ConsumerWidget {
  const DisplayGame({
    super.key,
    required this.game,
    this.homePlaceholder,
    this.awayPlaceholder,
  });

  final GameSummary game;

  /// I et slutspil: hvem der kommer til at stå på hjemme-/udepladsen, når
  /// den ikke er sat endnu (fx "Vinder af kvartfinale").
  final String? homePlaceholder;
  final String? awayPlaceholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userPermissions = ref.watch(userPermissionsProvider).value;
    final canReport =
        game.homeTeam?.id != null &&
        userPermissions?.canReportResults(game.homeTeam!.id) == true;
    final isAdmin = userPermissions?.isAdmin == true;
    final seasonId = ref.watch(currentSeasonProvider)?.id;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 10.0),
        child: Column(
          children: [
            _GameInfoRow(
              game: game,
              trailing: isAdmin
                  ? EditDeleteMenu(
                      onEdit: () =>
                          _showEditGameModal(context, game, seasonId),
                      confirmationFields: ConfirmationFields(
                        title: "Sletning af kamp",
                        content: "Du er ved at slette denne kamp",
                        confirmButtonText: "Slet",
                      ),
                      onDelete: (confirmed) async {
                        if (!confirmed || seasonId == null) return;
                        await ref
                            .read(gamesProvider(seasonId).notifier)
                            .deleteGame(game.id);
                      },
                    )
                  : null,
            ),
            const SizedBox(height: 10.0),
            _GameScoreRow(
              game: game,
              homePlaceholder: homePlaceholder,
              awayPlaceholder: awayPlaceholder,
            ),
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

  void _showEditGameModal(
    BuildContext context,
    GameSummary game,
    int? seasonId,
  ) {
    showCreateEntityModalBottomSheet(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final gameAsync = ref.watch(gameProvider(game.id));
          return gameAsync.when(
            data: (fullGame) {
              // AddEditGameModal (via CreateEntityModal) sætter kun sine
              // interne felt-værdier i initState(). Hvis gruppe-/hold-
              // listerne stadig loader, når modalen bygges første gang,
              // ender hjemmehold, udehold og dommer med at stå tomme, selv
              // om dataen kommer et øjeblik efter. Vi forvarmer derfor de
              // samme providers her, så de allerede har data klar, inden
              // AddEditGameModal mountes.
              final groupsAsync = seasonId != null
                  ? ref.watch(groupProvider(seasonId))
                  : null;
              final groupId = fullGame.group?.id;
              final teamsAsync = groupId != null
                  ? ref.watch(teamsByGroupProvider(groupId))
                  : null;
              // Slutspilskampe henter i stedet holdene blandt hele sæsonens
              // hold (ikke gruppebundet), så den provider forvarmes også.
              final seasonTeamsAsync =
                  fullGame.gameStageType == GameStageType.round &&
                      seasonId != null
                  ? ref.watch(seasonTeamsProvider(seasonId))
                  : null;

              final isLoading =
                  (groupsAsync?.isLoading ?? false) ||
                  (teamsAsync?.isLoading ?? false) ||
                  (seasonTeamsAsync?.isLoading ?? false);
              final error =
                  groupsAsync?.error ??
                  teamsAsync?.error ??
                  seasonTeamsAsync?.error;

              if (isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (error != null) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Kunne ikke indlæse kamp: $error"),
                );
              }

              return AddEditGameModal(game: fullGame);
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Kunne ikke indlæse kamp: $error"),
            ),
          );
        },
      ),
    );
  }
}

class _GameInfoRow extends StatelessWidget {
  const _GameInfoRow({required this.game, this.trailing});

  final GameSummary game;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final infoParts = <String>[
      if (game.group?.name != null) game.group!.name!,
      if (game.roundNumber != null) knockoutStageName(game.roundNumber!),
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
        ?trailing,
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
  const _GameScoreRow({
    required this.game,
    this.homePlaceholder,
    this.awayPlaceholder,
  });

  final GameSummary game;
  final String? homePlaceholder;
  final String? awayPlaceholder;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _TeamColumn(
            teamName: game.homeTeam?.name,
            placeholder: homePlaceholder,
          ),
        ),
        _ScoreBox(game: game),
        Expanded(
          child: _TeamColumn(
            teamName: game.awayTeam?.name,
            placeholder: awayPlaceholder,
          ),
        ),
      ],
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({required this.teamName, this.placeholder});

  final String? teamName;

  /// I et slutspil: hvem der kommer til at stå på pladsen, hvis holdet
  /// ikke er sat endnu (fx "Vinder af kvartfinale").
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = teamName ?? placeholder ?? "Ukendt hold";
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TeamIcon(teamName: teamName ?? "?"),
        const SizedBox(height: 6.0),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: teamName != null
              ? theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                )
              : theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
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

    // Kickoff-tidspunktet vises allerede i info-rækken øverst på kortet, så
    // her viser vi kun selve resultatet — eller en streg, hvis der endnu
    // ikke er indberettet noget resultat.
    final content = hasScore
        ? Text(
            "${game.homeScore} - ${game.awayScore}",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isLive ? Colors.red : theme.colorScheme.onSurface,
            ),
          )
        : Text(
            "-",
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );

    return Container(
      constraints: const BoxConstraints(minWidth: 56.0),
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      alignment: Alignment.center,
      child: content,
    );
  }
}
