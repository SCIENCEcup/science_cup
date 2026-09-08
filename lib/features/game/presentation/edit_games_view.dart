import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:science_cup_app/features/game/application/games_notifier.dart';
import 'package:science_cup_app/features/game/data/models/game_summary.dart';
import 'package:science_cup_app/features/game/presentation/add_edit_game_modal.dart';
import 'package:science_cup_app/features/game/presentation/display_game.dart';
import 'package:science_cup_app/features/season/application/active_season/current_season_provider.dart';
import 'package:science_cup_app/shared/presentation/modals/show_create_entity_modal_bottom_sheet.dart';

class EditGamesView extends ConsumerWidget {
  const EditGamesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        return Column(
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
            ...games.map((game) {
              return DisplayGame(game: game);
            }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text("Fejl: $error")),
    );
  }
}
