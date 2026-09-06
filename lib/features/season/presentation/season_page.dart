import 'package:dropdown_flutter/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:science_cup_app/core/navigation/season_tabs.dart';
import 'package:science_cup_app/core/presentation/widgets/auth_profile_button.dart';
import 'package:science_cup_app/features/season/data/models/season.dart';
import 'package:science_cup_app/features/season/presentation/add_season_button.dart';
import 'package:science_cup_app/features/season/presentation/admin/admin_season_view.dart';
import 'package:science_cup_app/features/standings/presentation/all_standings_view.dart';
import 'package:science_cup_app/features/team/application/team_notifier.dart';

import '../../auth/application/auth_notifier.dart';
import '../../game/presentation/games_view.dart';
import '../application/season/season_notifier.dart';

class SeasonPage extends ConsumerWidget {
  const SeasonPage({
    super.key,
    required this.seasonId,
    required this.activeTab,
  });

  final int seasonId;
  final SeasonTabs activeTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileRole = ref.read(authProvider).profileRole;
    final availableTabs = SeasonTabs.availableTabsForRole(profileRole);
    final seasonsState = ref.watch(seasonsProvider);
    final selectedIndex = activeTab.index;

    // Vi pakker staten ud på øverste niveau for hele skærmen
    return seasonsState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, error) => Center(child: Text('Der skete en fejl: $error')),
      data: (seasons) {
        // NU ved vi med 100% sikkerhed, at listen er klar og gyldig!

        // Find den aktive sæson ud fra URL'ens seasonId
        final currentSeason = seasons.firstWhere(
          (s) => s.id == seasonId,
          orElse: () => seasons.first,
        );

        return DefaultTabController(
          length: availableTabs.length,
          initialIndex: selectedIndex,
          child: Scaffold(
            appBar: AppBar(
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(child: Icon(Icons.sports_soccer)),
              ),
              title: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownFlutter<Season>.search(
                  initialItem: currentSeason,
                  items: seasons,
                  decoration: CustomDropdownDecoration(
                    closedFillColor: Colors.transparent,
                  ),
                  listItemBuilder: (context, season, _, _) =>
                      Text(season.name ?? "Ingen navn"),
                  headerBuilder: (context, season, _) =>
                      Text(season.name ?? "Ingen navn"),
                  onChanged: (newSeason) {
                    if (newSeason?.id != null) {
                      context.go('/seasons/${newSeason?.id}');
                    }
                  },
                ),
              ),
              centerTitle: false,
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: AddSeasonButton(
                    includeText: false,
                  ), // Tilføj sæson-knap uden tekst
                ),
                AuthProfileButton(),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(teamProvider(seasonId));
              },
              child: ConstrainedBox(
                // Udvider siden så den altid fylder hele skærmen, også når indholdet er lidt
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height - kToolbarHeight,
                ),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 5,
                          children: List.generate(availableTabs.length, (
                            index,
                          ) {
                            final indexTab = availableTabs[index];
                            return ChoiceChip(
                              showCheckmark: false,
                              avatar: switch (indexTab) {
                                SeasonTabs.games => const Icon(
                                  Icons.calendar_today_outlined,
                                ),
                                SeasonTabs.standings => const Icon(
                                  Icons.leaderboard_outlined,
                                ),
                                SeasonTabs.admin => const Icon(
                                  Icons.admin_panel_settings_outlined,
                                ),
                              },
                              label: Text(indexTab.title),
                              selected: index == selectedIndex,
                              onSelected: (selected) {
                                if (selected) {
                                  context.go(
                                    '/seasons/${currentSeason.id}/${indexTab.path}',
                                  );
                                }
                              },
                            );
                          }),
                        ),
                        const SizedBox(height: 16),
                        switch (activeTab) {
                          SeasonTabs.games => const GamesView(),
                          SeasonTabs.standings => const AllStandingsView(),
                          SeasonTabs.admin => const AdminSeasonView(),
                        },
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
