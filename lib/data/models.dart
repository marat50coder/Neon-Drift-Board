/// Result of a single gameplay run, produced by the engine and consumed
/// by the results screen + persistent stats.
class RunResult {
  final int score;
  final double distance; // meters
  final int spheres;
  final int crystals;
  final int credits;
  final int bestCombo;
  final int turbos;
  final int drifts;
  final int grazes;
  final int tricks;
  final bool delivered; // reached 100% route / survived the mode goal
  final bool crashed;
  final String rating; // Bronze | Silver | Gold | Platinum
  final String contractId;
  final String districtId;

  /// Which rule set produced this run (see `Modes`).
  final String modeId;

  /// Campaign level id, or null for free-play modes.
  final String? levelId;

  /// Per-objective completion for campaign runs (same order as the level def).
  final List<bool> objectivesMet;

  /// Mode-specific headline value: seconds survived, time left, hunter gap...
  final double modeValue;

  const RunResult({
    required this.score,
    required this.distance,
    required this.spheres,
    required this.crystals,
    required this.credits,
    required this.bestCombo,
    required this.turbos,
    required this.drifts,
    required this.delivered,
    required this.crashed,
    required this.rating,
    required this.contractId,
    required this.districtId,
    this.grazes = 0,
    this.tricks = 0,
    this.modeId = 'campaign',
    this.levelId,
    this.objectivesMet = const [],
    this.modeValue = 0,
  });

  /// Stars are only awarded on a successful campaign run.
  int get stars => !delivered || levelId == null
      ? 0
      : objectivesMet.where((e) => e).length;
}

class LeaderboardEntry {
  final String name;
  final int score;
  final String districtName;
  final int timestamp;
  const LeaderboardEntry({
    required this.name,
    required this.score,
    required this.districtName,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'score': score,
        'district': districtName,
        'ts': timestamp,
      };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        name: (j['name'] ?? 'Rider').toString(),
        score: (j['score'] ?? 0) as int,
        districtName: (j['district'] ?? '').toString(),
        timestamp: (j['ts'] ?? 0) as int,
      );
}

class DailyChallenge {
  final String id;
  final String title;
  final String stat; // stat key tracked per-run
  final int target;
  final int reward;
  int progress;
  bool claimed;

  DailyChallenge({
    required this.id,
    required this.title,
    required this.stat,
    required this.target,
    required this.reward,
    this.progress = 0,
    this.claimed = false,
  });

  bool get completed => progress >= target;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'stat': stat,
        'target': target,
        'reward': reward,
        'progress': progress,
        'claimed': claimed,
      };

  factory DailyChallenge.fromJson(Map<String, dynamic> j) => DailyChallenge(
        id: j['id'].toString(),
        title: j['title'].toString(),
        stat: j['stat'].toString(),
        target: (j['target'] ?? 1) as int,
        reward: (j['reward'] ?? 100) as int,
        progress: (j['progress'] ?? 0) as int,
        claimed: (j['claimed'] ?? false) as bool,
      );
}
