// presentation/modals/add_game_score_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:science_cup_app/features/game/application/game_result_notifier.dart';
import 'package:science_cup_app/features/game/data/models/game_summary.dart';
import 'package:science_cup_app/features/permissions/application/user_permissions_notifier.dart';
import 'package:science_cup_app/shared/presentation/modals/create_entity_modal.dart';
import 'package:science_cup_app/shared/presentation/widgets/confirmation_dialog/confirmation_dialog.dart';
import 'package:science_cup_app/shared/presentation/widgets/confirmation_dialog/confirmation_fields.dart';

class AddGameResultModal extends ConsumerWidget {
  const AddGameResultModal({super.key, required this.game});
  final GameSummary game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(gameResultProvider(game.id).notifier);
    final state = ref.watch(gameResultProvider(game.id));
    final isAdmin =
        ref.watch(userPermissionsProvider).value?.isAdmin == true;

    if (state.isInitialLoading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
        ],
      );
    }

    final hasReportedResult = state.homeScore != null && state.awayScore != null;

    return CreateEntityModal(
      title: 'Indberet resultat',
      fields: [
        state.errorMessage == null
            ? EmptyFieldConfig()
            : TextConfig(label: state.errorMessage!),
        TextFieldConfig(
          label: "Score: ${game.homeTeam?.name ?? "Hjemmehold"}",
          key: 'home_score',
          onlyNumbers: true,
          initialValue: state.homeScore?.toString(),
          onChanged: (value) {
            notifier.setHomeScore(value.isEmpty ? null : int.tryParse(value));
          },
        ),
        TextFieldConfig(
          label: "Score: ${game.awayTeam?.name ?? "Udehold"}",
          key: 'away_score',
          onlyNumbers: true,
          initialValue: state.awayScore?.toString(),
          onChanged: (value) {
            notifier.setAwayScore(value.isEmpty ? null : int.tryParse(value));
          },
        ),
        if (isAdmin && hasReportedResult)
          WidgetFieldConfig(
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final confirmed =
                      await showDialog<bool>(
                        context: context,
                        builder: (context) => ConfirmationDialog(
                          confirmationFields: ConfirmationFields(
                            title: "Ryd resultat",
                            content:
                                "Er du sikker på at du vil slette det indberettede resultat? Kampen vil herefter fremstå uden resultat.",
                            confirmButtonText: "Ryd",
                          ),
                        ),
                      ) ??
                      false;
                  if (!confirmed) return;

                  await notifier.clearResult();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Resultat ryddet')),
                    );
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 18.0),
                label: const Text("Ryd resultat"),
              ),
            ),
          ),
      ],
      onSubmit: (_) async {
        debugPrint(
          "Submitting game result for gameId: ${game.id}, homeScore: ${state.homeScore}, awayScore: ${state.awayScore}",
        );
        await notifier.submit();
        debugPrint("Finished submitting game result for gameId: ${game.id}");
      },
      isLoading: state.isSubmitting,
    );
  }
}
