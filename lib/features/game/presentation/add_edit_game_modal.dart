import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:science_cup_app/features/game/application/game_form_notifier.dart';
import 'package:science_cup_app/features/game/data/enums/game_enums.dart';
import 'package:science_cup_app/features/game/data/models/game.dart';
import 'package:science_cup_app/features/group/application/group_notifier.dart';
import 'package:science_cup_app/features/group/data/models/group.dart';
import 'package:science_cup_app/features/season/application/active_season/current_season_provider.dart';
import 'package:science_cup_app/features/team/application/team_providers.dart';
import 'package:science_cup_app/features/team/data/models/team.dart';
import 'package:science_cup_app/features/team/presentation/add_team_modal.dart';
import 'package:science_cup_app/shared/presentation/modals/create_entity_modal.dart';

class AddEditGameModal extends ConsumerWidget {
  const AddEditGameModal({super.key, this.game});
  final Game? game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Hent seasonId
    final seasonId = ref.watch(currentSeasonProvider)?.id;
    if (seasonId == null)
      return const Center(child: CircularProgressIndicator());

    // 2. Lyt på form-tilstand og få notifier
    final formState = ref.watch(gameFormProvider((seasonId, game)));
    final notifier = ref.read(gameFormProvider((seasonId, game)).notifier);

    // 3. Hent referencedata fra separate providers (bevarer adskillelse)
    final groupsAsync = ref.watch(groupProvider(seasonId));
    final teamsAsync = formState.groupId != null
        ? ref.watch(teamsByGroupProvider(formState.groupId!))
        : null;
    // Slutspilskampe er ikke bundet til en gruppe, så holdvalget her sker
    // blandt alle sæsonens hold i stedet for en enkelt gruppes.
    final seasonTeamsAsync = ref.watch(seasonTeamsProvider(seasonId));

    return CreateEntityModal(
      title: game == null ? 'Opret kamp' : 'Rediger kamp',
      fields: [
        // Kampskabelon – altid synlig
        SelectFieldConfig<GameStageType>(
          key: '_gameStageType',
          label: 'Kamp type',
          initialValue: formState.gameStageType,
          options: GameStageType.values,
          optionLabel: (o) => o.displayName,
          onFieldSelected: (value) => notifier.setGameStageType(value),
        ),

        // Resten vises kun, hvis vi er i gruppespil
        if (formState.gameStageType == GameStageType.group) ...[
          // Gruppe-dropdown
          groupsAsync.when(
            data: (groups) => SelectFieldConfig<Group?>(
              key: 'group',
              label: 'Gruppe',
              isClearable: false,
              options: groups,
              optionLabel: (g) => g?.name ?? '',
              initialValue: groups.firstWhereOrNull(
                (g) => g.id == formState.groupId,
              ),
              onFieldSelected: (g) => notifier.setGroupId(g?.id),
            ),
            loading: () => const EmptyFieldConfig(),
            error: (_, _) => const EmptyFieldConfig(),
          ),

          // Hjemmehold – kun hvis gruppe er valgt
          if (teamsAsync != null)
            teamsAsync.when(
              data: (teams) {
                final availableHome = teams
                    .where((t) => t.id != formState.awayTeamId)
                    .toList();
                return SelectFieldConfig<Team?>(
                  key: 'homeTeam',
                  label: 'Hjemmehold',
                  isClearable: true,
                  options: availableHome,
                  optionLabel: (t) => t?.name ?? 'Vælg hold',
                  initialValue: availableHome.firstWhereOrNull(
                    (t) => t.id == formState.homeTeamId,
                  ),
                  onFieldSelected: (t) => notifier.setHomeTeamId(t?.id),
                );
              },
              loading: () => const EmptyFieldConfig(),
              error: (_, _) => const EmptyFieldConfig(),
            ),

          // Udehold – kun hvis gruppe er valgt
          if (teamsAsync != null)
            teamsAsync.when(
              data: (teams) {
                final availableAway = teams
                    .where((t) => t.id != formState.homeTeamId)
                    .toList();
                return SelectFieldConfig<Team?>(
                  key: 'awayTeam',
                  label: 'Udehold',
                  isClearable: true,
                  options: availableAway,
                  optionLabel: (t) => t?.name ?? 'Vælg hold',
                  initialValue: availableAway.firstWhereOrNull(
                    (t) => t.id == formState.awayTeamId,
                  ),
                  onFieldSelected: (t) => notifier.setAwayTeamId(t?.id),
                );
              },
              loading: () => const EmptyFieldConfig(),
              error: (_, _) => const EmptyFieldConfig(),
            ),

          // Dato & tid
          DateFieldConfig(
            key: 'startDate',
            label: 'Dato',
            isClearable: true,
            initialValue: formState.startDate,
            onSubmit: (date) => notifier.setStartDate(date),
          ),
          TimeFieldConfig(
            key: 'startTime',
            label: 'Tid',
            isClearable: true,
            initialValue:
                formState.startTime ?? const TimeOfDay(hour: 15, minute: 0),
            onSubmit: (time) => notifier.setStartTime(time),
          ),

          // Dommer
          if (teamsAsync != null)
            teamsAsync.when(
              data: (teams) => SelectFieldConfig<Team?>(
                key: 'referee',
                label: 'Dommer',
                prefixIcon: const Icon(Icons.person),
                options: teams,
                optionLabel: (t) => t?.name ?? 'Ingen dommer',
                initialValue: teams.firstWhereOrNull(
                  (t) => t.id == formState.refereeTeamId,
                ),
                onFieldSelected: (t) => notifier.setRefereeTeamId(t?.id),
                createEntityWidget: const AddTeamModal(),
              ),
              loading: () => const EmptyFieldConfig(),
              error: (_, _) => const EmptyFieldConfig(),
            ),
        ],

        // Slutspil: kun antal runder, hvis vi opretter et nyt slutspil —
        // resten af bracket'et genereres automatisk. Redigerer man en
        // allerede oprettet slutspilskamp, sættes i stedet hold/dato/dommer
        // for netop den kamp; runde-nummeret er fastlagt af bracket'et og
        // kan ikke ændres her.
        if (formState.gameStageType == GameStageType.round && game == null)
          SelectFieldConfig<int>(
            key: 'roundCount',
            label: 'Antal runder',
            isClearable: false,
            options: const [1, 2, 3, 4, 5],
            optionLabel: (n) => knockoutRoundCountLabel(n),
            initialValue: formState.roundCount,
            onFieldSelected: (n) => notifier.setRoundCount(n),
          ),

        if (formState.gameStageType == GameStageType.round && game != null) ...[
          seasonTeamsAsync.when(
            data: (teams) {
              final availableHome = teams
                  .where((t) => t.id != formState.awayTeamId)
                  .toList();
              return SelectFieldConfig<Team?>(
                key: 'homeTeam',
                label: 'Hjemmehold',
                isClearable: true,
                options: availableHome,
                optionLabel: (t) => t?.name ?? 'Vælg hold',
                initialValue: availableHome.firstWhereOrNull(
                  (t) => t.id == formState.homeTeamId,
                ),
                onFieldSelected: (t) => notifier.setHomeTeamId(t?.id),
              );
            },
            loading: () => const EmptyFieldConfig(),
            error: (_, _) => const EmptyFieldConfig(),
          ),
          seasonTeamsAsync.when(
            data: (teams) {
              final availableAway = teams
                  .where((t) => t.id != formState.homeTeamId)
                  .toList();
              return SelectFieldConfig<Team?>(
                key: 'awayTeam',
                label: 'Udehold',
                isClearable: true,
                options: availableAway,
                optionLabel: (t) => t?.name ?? 'Vælg hold',
                initialValue: availableAway.firstWhereOrNull(
                  (t) => t.id == formState.awayTeamId,
                ),
                onFieldSelected: (t) => notifier.setAwayTeamId(t?.id),
              );
            },
            loading: () => const EmptyFieldConfig(),
            error: (_, _) => const EmptyFieldConfig(),
          ),
          DateFieldConfig(
            key: 'startDate',
            label: 'Dato',
            isClearable: true,
            initialValue: formState.startDate,
            onSubmit: (date) => notifier.setStartDate(date),
          ),
          TimeFieldConfig(
            key: 'startTime',
            label: 'Tid',
            isClearable: true,
            initialValue:
                formState.startTime ?? const TimeOfDay(hour: 15, minute: 0),
            onSubmit: (time) => notifier.setStartTime(time),
          ),
          seasonTeamsAsync.when(
            data: (teams) => SelectFieldConfig<Team?>(
              key: 'referee',
              label: 'Dommer',
              prefixIcon: const Icon(Icons.person),
              options: teams,
              optionLabel: (t) => t?.name ?? 'Ingen dommer',
              initialValue: teams.firstWhereOrNull(
                (t) => t.id == formState.refereeTeamId,
              ),
              onFieldSelected: (t) => notifier.setRefereeTeamId(t?.id),
              createEntityWidget: const AddTeamModal(),
            ),
            loading: () => const EmptyFieldConfig(),
            error: (_, _) => const EmptyFieldConfig(),
          ),
        ],
      ],
      onSubmit: (_) async {
        if (game == null && formState.gameStageType == GameStageType.round) {
          await notifier.submitPlayoffBracket();
        } else {
          await notifier.submit();
        }
      },
      // isLoading: formState.isSubmitting, // vis spinner på knap
    );
  }
}
