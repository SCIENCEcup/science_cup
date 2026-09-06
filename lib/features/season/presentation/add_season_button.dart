import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:science_cup_app/features/auth/data/profile_role.dart';
import 'package:science_cup_app/features/season/presentation/add_season_modal.dart';
import 'package:science_cup_app/shared/presentation/modals/show_create_entity_modal_bottom_sheet.dart';

import '../../auth/application/auth_notifier.dart';

class AddSeasonButton extends ConsumerWidget {
  const AddSeasonButton({super.key, this.includeText = true});
  final bool includeText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Læs din AuthNotifier uden at lytte (så knappen ikke genbygger unødigt)
    // Hvis du bruger standard ListenableBuilder, kan du fjerne context.watch/read
    final authNotifier = ref.watch(authProvider);
    final profile = authNotifier.profile;

    // 2. Hvis brugeren ikke er logget ind, ELLER hvis rollen ikke er admin, returnerer vi ingenting
    if (profile == null || profile.role != ProfileRole.admin) {
      return const SizedBox.shrink(); // Svarer til et usynligt, tomt felt (0x0px)
    }

    // 3. Hvis brugeren ER admin, viser vi den rigtige knap
    return includeText == false
        ? IconButton(
            onPressed: () => _showAddSeasonDialog(context),
            icon: Icon(Icons.add),
          )
        : FilledButton.icon(
            onPressed: () => _showAddSeasonDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Tilføj sæson'),
          );
  }

  void _showAddSeasonDialog(BuildContext context) {
    showCreateEntityModalBottomSheet(
      context: context,
      builder: (context) => AddSeasonModal(),
    );
  }
}
