import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalog.dart';
import 'levels.dart';
import 'models.dart';
import 'upgrades.dart';

/// Global persistent game state. Everything lives on-device (fully offline).
class GameState extends ChangeNotifier {
  late SharedPreferences _p;

  // Profile
  String playerName = 'Rider';
  String? avatarPath;

  // Economy
  int credits = 500;

  // Ownership
  Set<String> boards = {'board_classic'};
  Set<String> spheres = {'sphere_azure'};
  Set<String> trails = {'trail_ion'};
  Set<String> turbos = {'turbo_wings'};
  Set<String> districts = {'d1'};

  // Selection
  String board = 'board_classic';
  String sphere = 'sphere_azure';
  String trail = 'trail_ion';
  String turbo = 'turbo_wings';
  String district = 'd1';

  // Settings
  bool sfxOn = true;
  bool musicOn = true;
  double sfxVolume = 0.8;
  double musicVolume = 0.5;
  bool hapticsOn = true;
  bool showFx = true;
  String controlMode = 'swipe'; // swipe | buttons

  // Stats
  final Map<String, num> stats = {};

  // Daily challenges
  List<DailyChallenge> daily = [];
  String dailyDate = '';

  // Achievements
  Set<String> claimedAchievements = {};

  /// Campaign: best star count earned per level id (0..3).
  Map<String, int> levelStars = {};

  /// Campaign: levels finished at least once. Kept apart from [levelStars] so
  /// a clean finish with no optional objectives still unlocks the next route.
  Set<String> clearedLevels = {};

  /// Permanent upgrade levels per upgrade id.
  Map<String, int> upgradeLevels = {};

  /// Whether the player has seen the how-to-play flow.
  bool tutorialSeen = false;

  // Leaderboard
  List<LeaderboardEntry> leaderboard = [];

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    playerName = _p.getString('playerName') ?? 'Rider';
    avatarPath = _p.getString('avatarPath');
    credits = _p.getInt('credits') ?? 500;

    boards = _set('boards', {'board_classic'});
    spheres = _set('spheres', {'sphere_azure'});
    trails = _set('trails', {'trail_ion'});
    turbos = _set('turbos', {'turbo_wings'});
    districts = _set('districts', {'d1'});

    board = _p.getString('sel_board') ?? 'board_classic';
    sphere = _p.getString('sel_sphere') ?? 'sphere_azure';
    trail = _p.getString('sel_trail') ?? 'trail_ion';
    turbo = _p.getString('sel_turbo') ?? 'turbo_wings';
    district = _p.getString('sel_district') ?? 'd1';

    sfxOn = _p.getBool('sfxOn') ?? true;
    musicOn = _p.getBool('musicOn') ?? true;
    sfxVolume = _p.getDouble('sfxVolume') ?? 0.8;
    musicVolume = _p.getDouble('musicVolume') ?? 0.5;
    hapticsOn = _p.getBool('hapticsOn') ?? true;
    showFx = _p.getBool('showFx') ?? true;
    controlMode = _p.getString('controlMode') ?? 'swipe';

    final statsJson = _p.getString('stats');
    stats.clear();
    if (statsJson != null) {
      final m = jsonDecode(statsJson) as Map<String, dynamic>;
      m.forEach((k, v) => stats[k] = (v as num));
    }

    claimedAchievements = _set('claimedAch', {});
    levelStars = _intMap('levelStars');
    // Levels starred before this key existed were, by definition, cleared.
    clearedLevels = _set('clearedLevels', levelStars.keys.toSet());
    upgradeLevels = _intMap('upgradeLevels');
    tutorialSeen = _p.getBool('tutorialSeen') ?? false;

    final lb = _p.getString('leaderboard');
    if (lb != null) {
      leaderboard = (jsonDecode(lb) as List)
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    _ensureDaily();
    _loaded = true;
    notifyListeners();
  }

  Set<String> _set(String key, Set<String> def) {
    final l = _p.getStringList(key);
    return l == null ? {...def} : l.toSet();
  }

  Map<String, int> _intMap(String key) {
    final raw = _p.getString(key);
    if (raw == null) return {};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return m.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  num stat(String key) => stats[key] ?? 0;

  // ---------------------------------------------------------------------------
  // Campaign progression
  // ---------------------------------------------------------------------------

  /// Stars earned on a level (0 = not cleared).
  int starsFor(String levelId) => levelStars[levelId] ?? 0;

  bool levelCleared(String levelId) => clearedLevels.contains(levelId);

  int get totalStars =>
      levelStars.values.fold(0, (sum, s) => sum + s);

  /// Levels unlock in order; the first is always available.
  bool levelUnlocked(LevelDef level) {
    if (level.number <= 1) return true;
    final prev = Campaign.levels[level.number - 2];
    return levelCleared(prev.id);
  }

  LevelDef get nextLevel => Campaign.levels.firstWhere(
        (l) => !levelCleared(l.id),
        orElse: () => Campaign.levels.last,
      );

  int get campaignCleared =>
      Campaign.levels.where((l) => levelCleared(l.id)).length;

  void _recordLevel(String levelId, int stars) {
    if (clearedLevels.add(levelId)) {
      _p.setStringList('clearedLevels', clearedLevels.toList());
    }
    if (stars <= starsFor(levelId)) return;
    levelStars[levelId] = stars;
    _p.setString('levelStars', jsonEncode(levelStars));
  }

  // ---------------------------------------------------------------------------
  // Upgrades
  // ---------------------------------------------------------------------------

  int upgradeLevel(String id) => upgradeLevels[id] ?? 0;

  bool upgradeMaxed(UpgradeDef u) => upgradeLevel(u.id) >= u.maxLevel;

  /// Cost of the next level, or null when fully upgraded.
  int? upgradeCost(UpgradeDef u) =>
      upgradeMaxed(u) ? null : u.costAt(upgradeLevel(u.id));

  bool buyUpgrade(UpgradeDef u) {
    final cost = upgradeCost(u);
    if (cost == null || credits < cost) return false;
    credits -= cost;
    upgradeLevels[u.id] = upgradeLevel(u.id) + 1;
    _p.setInt('credits', credits);
    _p.setString('upgradeLevels', jsonEncode(upgradeLevels));
    notifyListeners();
    return true;
  }

  UpgradeStats get upgradeStats => UpgradeStats.from(upgradeLevels);

  void markTutorialSeen() {
    if (tutorialSeen) return;
    tutorialSeen = true;
    _p.setBool('tutorialSeen', true);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Economy & ownership
  // ---------------------------------------------------------------------------
  bool owns(String kind, String id) => _bucket(kind).contains(id);

  Set<String> _bucket(String kind) {
    switch (kind) {
      case 'board':
        return boards;
      case 'sphere':
        return spheres;
      case 'trail':
        return trails;
      case 'turbo':
        return turbos;
      case 'district':
        return districts;
      default:
        return {};
    }
  }

  bool buy(String kind, String id, int price) {
    if (owns(kind, id)) return true;
    if (credits < price) return false;
    credits -= price;
    _bucket(kind).add(id);
    _persistBucket(kind);
    _p.setInt('credits', credits);
    _checkAchievements();
    _save();
    notifyListeners();
    return true;
  }

  void select(String kind, String id) {
    switch (kind) {
      case 'board':
        board = id;
        _p.setString('sel_board', id);
        break;
      case 'sphere':
        sphere = id;
        _p.setString('sel_sphere', id);
        break;
      case 'trail':
        trail = id;
        _p.setString('sel_trail', id);
        break;
      case 'turbo':
        turbo = id;
        _p.setString('sel_turbo', id);
        break;
      case 'district':
        district = id;
        _p.setString('sel_district', id);
        break;
    }
    notifyListeners();
  }

  void _persistBucket(String kind) {
    _p.setStringList(kind == 'board'
        ? 'boards'
        : kind == 'sphere'
            ? 'spheres'
            : kind == 'trail'
                ? 'trails'
                : kind == 'turbo'
                    ? 'turbos'
                    : 'districts',
        _bucket(kind).toList());
  }

  void addCredits(int amount) {
    credits += amount;
    _p.setInt('credits', credits);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Profile & settings
  // ---------------------------------------------------------------------------
  void setName(String name) {
    playerName = name.trim().isEmpty ? 'Rider' : name.trim();
    _p.setString('playerName', playerName);
    notifyListeners();
  }

  void setAvatar(String? path) {
    avatarPath = path;
    if (path == null) {
      _p.remove('avatarPath');
    } else {
      _p.setString('avatarPath', path);
    }
    notifyListeners();
  }

  void updateSettings({
    bool? sfx,
    bool? music,
    double? sfxVol,
    double? musicVol,
    bool? haptics,
    bool? fx,
    String? control,
  }) {
    if (sfx != null) sfxOn = sfx;
    if (music != null) musicOn = music;
    if (sfxVol != null) sfxVolume = sfxVol;
    if (musicVol != null) musicVolume = musicVol;
    if (haptics != null) hapticsOn = haptics;
    if (fx != null) showFx = fx;
    if (control != null) controlMode = control;
    _p.setBool('sfxOn', sfxOn);
    _p.setBool('musicOn', musicOn);
    _p.setDouble('sfxVolume', sfxVolume);
    _p.setDouble('musicVolume', musicVolume);
    _p.setBool('hapticsOn', hapticsOn);
    _p.setBool('showFx', showFx);
    _p.setString('controlMode', controlMode);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Run recording
  // ---------------------------------------------------------------------------
  void recordRun(RunResult r) {
    _inc('totalRuns', 1);
    _inc('totalScore', r.score);
    _inc('distance', r.distance);
    _inc('turbos', r.turbos);
    _inc('drifts', r.drifts);
    _inc('spheresCollected', r.spheres);
    _inc('crystalsCollected', r.crystals);
    _inc('creditsEarned', r.credits);
    _inc('grazes', r.grazes);
    _inc('tricks', r.tricks);
    if (r.modeId == 'flight') _inc('rings', r.modeValue.round());
    if (r.modeId == 'boss' && r.delivered) _inc('bossKills', 1);
    _inc('timePlayed', (r.distance / 60).clamp(1, 600));
    if (r.delivered) _inc('deliveries', 1);
    if (r.rating == 'Gold' || r.rating == 'Platinum') _inc('goldRuns', 1);
    if (!r.crashed) _inc('perfectRuns', 1);
    _max('bestScore', r.score);
    _max('bestCombo', r.bestCombo);
    _max('bestDistance', r.distance);

    credits += r.credits;
    _p.setInt('credits', credits);

    // Campaign: bank the best star result and pay the one-off clear bonus.
    final levelId = r.levelId;
    if (levelId != null && r.delivered) {
      final firstClear = !levelCleared(levelId);
      _recordLevel(levelId, r.stars);
      if (firstClear) {
        final bonus = Campaign.byId(levelId).reward;
        credits += bonus;
        _inc('creditsEarned', bonus);
        _p.setInt('credits', credits);
      }
      stats['campaignStars'] = totalStars;
    }

    _progressDaily('deliveries', r.delivered ? 1 : 0);
    _progressDaily('distance', r.distance.round());
    _progressDaily('turbos', r.turbos);
    _progressDaily('drifts', r.drifts);
    _progressDaily('spheres', r.spheres);
    _progressDaily('crystals', r.crystals);

    _addLeaderboard(LeaderboardEntry(
      name: playerName,
      score: r.score,
      districtName: Catalog.districts
          .firstWhere((d) => d.id == r.districtId,
              orElse: () => Catalog.districts.first)
          .name,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));

    _checkAchievements();
    _save();
    notifyListeners();
  }

  void _inc(String key, num v) => stats[key] = (stats[key] ?? 0) + v;
  void _max(String key, num v) =>
      stats[key] = max(stats[key] ?? 0, v);

  void _addLeaderboard(LeaderboardEntry e) {
    leaderboard.add(e);
    leaderboard.sort((a, b) => b.score.compareTo(a.score));
    if (leaderboard.length > 20) {
      leaderboard = leaderboard.sublist(0, 20);
    }
  }

  // ---------------------------------------------------------------------------
  // Daily challenges
  // ---------------------------------------------------------------------------
  static final List<DailyChallenge> _dailyPool = [
    DailyChallenge(id: 'dc_deliver', title: 'Complete 3 deliveries', stat: 'deliveries', target: 3, reward: 500),
    DailyChallenge(id: 'dc_distance', title: 'Ride 3000 m in total', stat: 'distance', target: 3000, reward: 400),
    DailyChallenge(id: 'dc_turbo', title: 'Use turbo 10 times', stat: 'turbos', target: 10, reward: 350),
    DailyChallenge(id: 'dc_drift', title: 'Perform 15 drifts', stat: 'drifts', target: 15, reward: 350),
    DailyChallenge(id: 'dc_spheres', title: 'Collect 25 spheres', stat: 'spheres', target: 25, reward: 400),
    DailyChallenge(id: 'dc_crystals', title: 'Collect 20 crystals', stat: 'crystals', target: 20, reward: 400),
  ];

  void _ensureDaily() {
    final today = _todayKey();
    dailyDate = _p.getString('dailyDate') ?? '';
    final saved = _p.getString('daily');
    if (dailyDate == today && saved != null) {
      daily = (jsonDecode(saved) as List)
          .map((e) => DailyChallenge.fromJson(e as Map<String, dynamic>))
          .toList();
      return;
    }
    // Generate a fresh set of 3 for today.
    final seed = today.hashCode;
    final rng = Random(seed);
    final pool = [..._dailyPool]..shuffle(rng);
    daily = pool
        .take(3)
        .map((d) => DailyChallenge(
              id: d.id,
              title: d.title,
              stat: d.stat,
              target: d.target,
              reward: d.reward,
            ))
        .toList();
    dailyDate = today;
    _p.setString('dailyDate', dailyDate);
    _saveDaily();
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  void _progressDaily(String stat, int amount) {
    if (amount <= 0) return;
    for (final d in daily) {
      if (d.stat == stat && !d.completed) {
        d.progress += amount;
      }
    }
    _saveDaily();
  }

  bool claimDaily(DailyChallenge d) {
    if (!d.completed || d.claimed) return false;
    d.claimed = true;
    credits += d.reward;
    _p.setInt('credits', credits);
    _saveDaily();
    notifyListeners();
    return true;
  }

  void _saveDaily() {
    _p.setString('daily', jsonEncode(daily.map((e) => e.toJson()).toList()));
  }

  // ---------------------------------------------------------------------------
  // Achievements
  // ---------------------------------------------------------------------------
  num achievementProgress(AchievementDef a) {
    switch (a.stat) {
      case 'boardsOwned':
        return boards.length;
      case 'districtsOwned':
        return districts.length;
      case 'campaignStars':
        return totalStars;
      case 'levelsCleared':
        return campaignCleared;
      case 'upgradesOwned':
        return upgradeLevels.values.fold<int>(0, (s, v) => s + v);
      default:
        return stat(a.stat);
    }
  }

  bool achievementUnlocked(AchievementDef a) =>
      achievementProgress(a) >= a.target;

  bool achievementClaimed(AchievementDef a) =>
      claimedAchievements.contains(a.id);

  bool claimAchievement(AchievementDef a) {
    if (!achievementUnlocked(a) || achievementClaimed(a)) return false;
    claimedAchievements.add(a.id);
    credits += a.reward;
    _p.setInt('credits', credits);
    _p.setStringList('claimedAch', claimedAchievements.toList());
    notifyListeners();
    return true;
  }

  void _checkAchievements() {
    // Nothing auto-claims; this is a hook for future auto-unlock toasts.
  }

  // ---------------------------------------------------------------------------
  // Persistence helpers
  // ---------------------------------------------------------------------------
  void _save() {
    _p.setString('stats', jsonEncode(stats));
    _p.setString(
        'leaderboard', jsonEncode(leaderboard.map((e) => e.toJson()).toList()));
  }

  Future<void> resetProgress() async {
    await _p.clear();
    playerName = 'Rider';
    avatarPath = null;
    credits = 500;
    boards = {'board_classic'};
    spheres = {'sphere_azure'};
    trails = {'trail_ion'};
    turbos = {'turbo_wings'};
    districts = {'d1'};
    board = 'board_classic';
    sphere = 'sphere_azure';
    trail = 'trail_ion';
    turbo = 'turbo_wings';
    district = 'd1';
    stats.clear();
    claimedAchievements = {};
    levelStars = {};
    clearedLevels = {};
    upgradeLevels = {};
    tutorialSeen = false;
    leaderboard = [];
    daily = [];
    dailyDate = '';
    _ensureDaily();
    notifyListeners();
  }
}
