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

class SeasonPage extends ConsumerStatefulWidget {
  const SeasonPage({
    super.key,
    required this.seasonId,
    required this.activeTab,
  });

  final int seasonId;
  final SeasonTabs activeTab;

  @override
  ConsumerState<SeasonPage> createState() => _SeasonPageState();
}

class _SeasonPageState extends ConsumerState<SeasonPage> {
  // Kampene for i dag er det mest relevante udgangspunkt, når man åbner
  // siden, så datofilteret starter valgt på dags dato i stedet for "Alle".
  DateTime? _selectedGameDate = _startOfToday();

  // Som standard vises kampe for den valgte dato. Slår man "alle kampe"
  // til, vises hele sæsonens kampe i stedet, med hold-/gruppefiltre.
  bool _showAllGames = false;

  @override
  void didUpdateWidget(covariant SeasonPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Datofilteret hører til den enkelte sæsons kampe, så det giver ikke
    // mening at bevare det, hvis brugeren skifter sæson.
    if (oldWidget.seasonId != widget.seasonId) {
      _selectedGameDate = _startOfToday();
      _showAllGames = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileRole = ref.read(authProvider).profileRole;
    final availableTabs = SeasonTabs.availableTabsForRole(profileRole);
    final seasonsState = ref.watch(seasonsProvider);
    final selectedIndex = widget.activeTab.index;

    // Vi pakker staten ud på øverste niveau for hele skærmen
    return seasonsState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, error) => Center(child: Text('Der skete en fejl: $error')),
      data: (seasons) {
        // NU ved vi med 100% sikkerhed, at listen er klar og gyldig!

        // Find den aktive sæson ud fra URL'ens seasonId
        final currentSeason = seasons.firstWhere(
          (s) => s.id == widget.seasonId,
          orElse: () => seasons.first,
        );

        return Scaffold(
          appBar: AppBar(
            leading: const AuthProfileButton(),
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
              if (widget.activeTab == SeasonTabs.games)
                IconButton(
                  tooltip: _showAllGames ? "Vis efter dato" : "Vis alle kampe",
                  icon: Icon(_showAllGames ? Icons.calendar_today : Icons.list),
                  onPressed: () => setState(() {
                    _showAllGames = !_showAllGames;
                    // Datofilteret hører kun til dato-visningen: ryd det,
                    // når vi skifter til liste-visning (så man ser alle
                    // kampe), og sæt det til dags dato igen, når vi
                    // skifter tilbage til dato-visningen — ellers viser
                    // dato-visningen ingen kampe, hvis filteret blev
                    // ryddet, mens man var i liste-visning.
                    _selectedGameDate = _showAllGames
                        ? null
                        : _startOfToday();
                  }),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: AddSeasonButton(
                  includeText: false,
                ), // Tilføj sæson-knap uden tekst
              ),
              IconButton(
                tooltip: "Om appen",
                icon: const Icon(Icons.info_outline),
                onPressed: () => context.push('/about'),
              ),
            ],
            // Viser datoerne, hvor sæsonen faktisk har kampe, i bunden af
            // app-baren — men kun på "Kampe"-fanen, og kun når man ikke er
            // i "alle kampe"-visningen.
            bottom: widget.activeTab == SeasonTabs.games && !_showAllGames
                ? GameDateBar(
                    seasonId: widget.seasonId,
                    selectedDate: _selectedGameDate,
                    onDateChanged: (date) =>
                        setState(() => _selectedGameDate = date),
                  )
                : null,
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(teamProvider(widget.seasonId));
            },
            child: ConstrainedBox(
              // Udvider siden så den altid fylder hele skærmen, også når indholdet er lidt
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - kToolbarHeight,
              ),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: switch (widget.activeTab) {
                    SeasonTabs.games => GamesView(
                      showAllGames: _showAllGames,
                      selectedDate: _selectedGameDate,
                      onDateChanged: (date) =>
                          setState(() => _selectedGameDate = date),
                    ),
                    SeasonTabs.standings => const AllStandingsView(),
                    SeasonTabs.admin => const AdminSeasonView(),
                  },
                ),
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              final tab = availableTabs[index];
              context.go('/seasons/${currentSeason.id}/${tab.path}');
            },
            destinations: [
              for (final tab in availableTabs)
                NavigationDestination(icon: Icon(tab.icon), label: tab.title),
            ],
          ),
        );
      },
    );
  }
}

DateTime _startOfToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
