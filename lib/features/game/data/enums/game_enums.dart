enum GameStatus { pending, ready, playing, completed }

enum GameSlot { home, away }

enum GameResolution { walkover, retired }

enum GameStageType {
  group("Gruppe"),
  round("Slutspil");

  final String displayName;
  const GameStageType(this.displayName);
}

/// Navnet på en slutspils-runde ud fra `round_number` (0 = finalen,
/// 1 = semifinalen, 2 = kvartfinalen, osv.).
String knockoutStageName(int roundNumber) {
  return switch (roundNumber) {
    0 => "Finale",
    1 => "Semifinale",
    2 => "Kvartfinale",
    3 => "Ottendedelsfinale",
    4 => "Sekstendedelsfinale",
    _ => "Runde ${roundNumber + 1}",
  };
}

/// Beskriver et slutspil ud fra antallet af runder (1 = kun en finale,
/// 2 = semifinale + finale osv.), til brug i "Antal runder"-vælgeren, når
/// man opretter et nyt slutspil.
String knockoutRoundCountLabel(int roundCount) {
  final teamCount = 1 << roundCount; // 2^roundCount
  final entryStage = knockoutStageName(roundCount - 1);
  return "$roundCount ${roundCount == 1 ? 'runde' : 'runder'} — $entryStage ($teamCount hold)";
}
