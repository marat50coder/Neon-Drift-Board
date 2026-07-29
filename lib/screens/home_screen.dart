import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/audio.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../data/levels.dart';
import '../game/sprites.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_background.dart';
import '../widgets/ui_kit.dart';
import 'about_screen.dart';
import 'achievements_screen.dart';
import 'campaign_screen.dart';
import 'contracts_screen.dart';
import 'cosmetic_gallery_screen.dart';
import 'daily_screen.dart';
import 'districts_screen.dart';
import 'leaderboard_screen.dart';
import 'level_brief_screen.dart';
import 'modes_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'stats_screen.dart';
import 'tutorial_screen.dart';
import 'upgrades_screen.dart';
import 'webview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _privacyUrl = 'https://neondriftboard.com/privacy-policy.html';
  static const _supportUrl = 'https://neondriftboard.com/support.html';

  @override
  void initState() {
    super.initState();
    // First launch walks the player through the controls and skill systems.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<GameState>().tutorialSeen) return;
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TutorialScreen()));
    });
  }

  void _go(BuildContext context, Widget screen) {
    Audio.I.play('open');
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final board = Catalog.boardById(gs.board);
    final district = Catalog.districts.firstWhere((d) => d.id == gs.district,
        orElse: () => Catalog.districts.first);

    return Scaffold(
      body: NeonBackground(
        accent: AppColors.cyan,
        accent2: AppColors.magenta,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            children: [
              _topBar(context, gs),
              const SizedBox(height: 14),
              _hero(context, board, district, gs)
                  .animate()
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.12),
              const SizedBox(height: 18),
              _section('PLAY', AppColors.magenta),
              const SizedBox(height: 10),
              _playBento(context, gs),
              const SizedBox(height: 18),
              _section('CUSTOMIZE', AppColors.cyan),
              const SizedBox(height: 10),
              _customizeBento(context, board),
              const SizedBox(height: 18),
              _section('PROGRESS', AppColors.gold),
              const SizedBox(height: 10),
              _progressBento(context, gs),
              const SizedBox(height: 18),
              _section('SYSTEM', AppColors.purple),
              const SizedBox(height: 10),
              _systemBento(context),
            ],
          ),
        ),
      ),
    );
  }

  // ---- top bar -----------------------------------------------------------
  Widget _topBar(BuildContext context, GameState gs) {
    final avatar = gs.avatarPath;
    final hasAvatar = avatar != null && File(avatar).existsSync();
    final deliveries = gs.stat('deliveries');
    final level = 1 + deliveries ~/ 5;
    final xp = (deliveries % 5) / 5.0;
    return Row(
      children: [
        GestureDetector(
          onTap: () => _go(context, const ProfileScreen()),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: CircularProgressIndicator(
                    value: xp,
                    strokeWidth: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.10),
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.cyan),
                  ),
                ),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.surfaceHigh,
                  backgroundImage:
                      hasAvatar ? FileImage(File(avatar)) : null,
                  child: hasAvatar
                      ? null
                      : const Icon(Icons.person_rounded,
                          color: AppColors.textMid, size: 22),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(gs.playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: AppText.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Colors.white)),
              Text('LEVEL $level',
                  style: const TextStyle(
                      fontFamily: AppText.body,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      color: AppColors.cyan)),
            ],
          ),
        ),
        CreditChip(credits: gs.credits),
        const SizedBox(width: 8),
        NeonIconButton(
          icon: Icons.settings_rounded,
          size: 42,
          color: AppColors.textMid,
          onTap: () => _go(context, const SettingsScreen()),
        ),
      ],
    );
  }

  // ---- hero --------------------------------------------------------------
  Widget _hero(BuildContext context, CosmeticItem board, District district,
      GameState gs) {
    final bg =
        'assets/Neon_Drift_Board_gameplay_assets/bg_location_${district.index + 1}_asset.webp';
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: SizedBox(
        height: 320,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(bg, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.bgDeep.withValues(alpha: 0.35),
                    AppColors.bgDeep.withValues(alpha: 0.55),
                    AppColors.bgDeep.withValues(alpha: 0.95),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.black.withValues(alpha: 0.4),
                          border: Border.all(
                              color: AppColors.cyan.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 14, color: AppColors.cyan),
                            const SizedBox(width: 5),
                            Text(district.name.toUpperCase(),
                                style: const TextStyle(
                                    fontFamily: AppText.display,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    letterSpacing: 1,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _go(context, const DistrictsScreen()),
                        child: const Text('CHANGE',
                            style: TextStyle(
                                fontFamily: AppText.display,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 1,
                                color: AppColors.cyan)),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 150,
                          child: SpriteView(
                              sheet: Sprites.boards, index: board.spriteIndex),
                        )
                            .animate(
                                onPlay: (c) => c.repeat(reverse: true))
                            .moveY(
                                begin: -6,
                                end: 6,
                                duration: 2200.ms,
                                curve: Curves.easeInOut),
                      ],
                    ),
                  ),
                  Text(board.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: AppText.display,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 1.5,
                          color: Colors.white)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: NeonButton(
                          label: gs.campaignCleared == 0 ? 'Start' : 'Continue',
                          icon: Icons.play_arrow_rounded,
                          height: 56,
                          onTap: () => _go(
                              context, LevelBriefScreen(level: gs.nextLevel)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _heroStat(
                          Icons.military_tech_rounded,
                          _fmt(gs.stat('bestScore')),
                          'BEST'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroStat(IconData icon, String value, String label) {
    return Container(
      width: 84,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.black.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.gold, size: 16),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: AppText.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Colors.white)),
          Text(label,
              style: const TextStyle(
                  fontFamily: AppText.body,
                  fontSize: 8,
                  letterSpacing: 1,
                  color: AppColors.textMid)),
        ],
      ),
    );
  }

  // ---- bento sections ----------------------------------------------------
  Widget _playBento(BuildContext context, GameState gs) {
    final cleared = gs.campaignCleared;
    final total = Campaign.levels.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 104,
          child: _BentoTile(
            title: 'Campaign',
            subtitle: '$cleared / $total routes · ${gs.totalStars}★',
            icon: Icons.route_rounded,
            color: AppColors.cyan,
            onTap: () => _go(context, const CampaignScreen()),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 104,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: _BentoTile(
                  title: 'Game Modes',
                  subtitle: '${Modes.all.length} rule sets',
                  icon: Icons.grid_view_rounded,
                  color: AppColors.magenta,
                  onTap: () => _go(context, const ModesScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BentoTile(
                  title: 'Workshop',
                  icon: Icons.build_rounded,
                  color: AppColors.blue,
                  onTap: () => _go(context, const UpgradesScreen()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 104,
          child: Row(
            children: [
              Expanded(
                child: _BentoTile(
                  title: 'Duel',
                  subtitle: 'Gunship',
                  icon: Icons.gps_fixed_rounded,
                  color: AppColors.danger,
                  onTap: () => _go(
                      context, const ContractsScreen(mode: GameMode.boss)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BentoTile(
                  title: 'Flight',
                  subtitle: 'No lanes',
                  icon: Icons.open_with_rounded,
                  color: AppColors.blue,
                  onTap: () => _go(
                      context, const ContractsScreen(mode: GameMode.flight)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _customizeBento(BuildContext context, CosmeticItem board) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 138,
          child: _BentoTile(
            title: 'Garage',
            subtitle: board.name,
            icon: Icons.snowboarding_rounded,
            color: AppColors.cyan,
            onTap: () => _go(context, _boards()),
            art: SpriteView(sheet: Sprites.boards, index: board.spriteIndex),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 104,
          child: Row(
            children: [
              Expanded(
                child: _BentoTile(
                  title: 'Spheres',
                  icon: Icons.blur_circular_rounded,
                  color: AppColors.magenta,
                  onTap: () => _go(context, _spheres()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BentoTile(
                  title: 'Trails',
                  icon: Icons.air_rounded,
                  color: AppColors.purple,
                  onTap: () => _go(context, _trails()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BentoTile(
                  title: 'Turbo',
                  icon: Icons.bolt_rounded,
                  color: AppColors.pink,
                  onTap: () => _go(context, _turbos()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 104,
          child: _BentoTile(
            title: 'Market',
            subtitle: 'Spend credits',
            icon: Icons.storefront_rounded,
            color: AppColors.gold,
            onTap: () => _go(context, const ShopScreen()),
          ),
        ),
      ],
    );
  }

  Widget _progressBento(BuildContext context, GameState gs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 104,
          child: Row(
            children: [
              Expanded(
                child: _BentoTile(
                  title: 'Daily',
                  icon: Icons.today_rounded,
                  color: AppColors.green,
                  onTap: () => _go(context, const DailyScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BentoTile(
                  title: 'Awards',
                  icon: Icons.emoji_events_rounded,
                  color: AppColors.gold,
                  onTap: () => _go(context, const AchievementsScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BentoTile(
                  title: 'Stats',
                  icon: Icons.bar_chart_rounded,
                  color: AppColors.blue,
                  onTap: () => _go(context, const StatsScreen()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 104,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: _BentoTile(
                  title: 'Leaderboard',
                  subtitle: 'Top couriers',
                  icon: Icons.leaderboard_rounded,
                  color: AppColors.gold,
                  onTap: () => _go(context, const LeaderboardScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BentoTile(
                  title: 'Profile',
                  icon: Icons.person_rounded,
                  color: AppColors.cyan,
                  onTap: () => _go(context, const ProfileScreen()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _systemBento(BuildContext context) {
    return SizedBox(
      height: 84,
      child: Row(
        children: [
          Expanded(
            child: _BentoTile(
              title: 'Guide',
              icon: Icons.school_rounded,
              color: AppColors.green,
              compact: true,
              onTap: () => _go(context, const TutorialScreen()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _BentoTile(
              title: 'Privacy',
              icon: Icons.privacy_tip_rounded,
              color: AppColors.cyan,
              compact: true,
              onTap: () => _go(
                  context,
                  const WebViewScreen(
                      title: 'Privacy Policy',
                      url: _privacyUrl,
                      assetFallback: 'assets/legal/privacy_policy.html',
                      accent: AppColors.cyan)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _BentoTile(
              title: 'Support',
              icon: Icons.support_agent_rounded,
              color: AppColors.magenta,
              compact: true,
              onTap: () => _go(
                  context,
                  const WebViewScreen(
                      title: 'Support',
                      url: _supportUrl,
                      assetFallback: 'assets/legal/support.html',
                      accent: AppColors.magenta)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _BentoTile(
              title: 'About',
              icon: Icons.info_rounded,
              color: AppColors.purple,
              compact: true,
              onTap: () => _go(context, const AboutScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontFamily: AppText.display,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 2,
                color: AppColors.textHigh)),
      ],
    );
  }

  static String _fmt(num v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  Widget _boards() => const CosmeticGalleryScreen(
        title: 'Garage',
        subtitle: 'Choose your levitating board',
        kind: 'board',
        items: Catalog.boards,
        sheet: Sprites.boards,
        accent: AppColors.cyan,
        layout: GalleryLayout.carousel,
      );

  Widget _spheres() => const CosmeticGalleryScreen(
        title: 'Spheres',
        subtitle: 'Collect every energy sphere',
        kind: 'sphere',
        items: Catalog.spheres,
        sheet: Sprites.spheres,
        accent: AppColors.magenta,
        layout: GalleryLayout.grid,
      );

  Widget _trails() => const CosmeticGalleryScreen(
        title: 'Trails',
        subtitle: 'Leave your mark on the city',
        kind: 'trail',
        items: Catalog.trails,
        sheet: Sprites.trails,
        accent: AppColors.purple,
        layout: GalleryLayout.list,
      );

  Widget _turbos() => const CosmeticGalleryScreen(
        title: 'Turbo FX',
        subtitle: 'Style your turbo bursts',
        kind: 'turbo',
        items: Catalog.turbos,
        sheet: Sprites.turbo,
        accent: AppColors.pink,
        layout: GalleryLayout.masterDetail,
      );
}

/// A bento-style navigation tile. Optional [art] renders a large preview on
/// the right; [compact] centres a smaller icon+label for secondary actions.
class _BentoTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Widget? art;
  final bool compact;

  const _BentoTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.subtitle,
    this.art,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Audio.I.play('click');
        onTap();
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                  color.withValues(alpha: 0.18), AppColors.surfaceHigh),
              Color.alphaBlend(
                  color.withValues(alpha: 0.04), AppColors.surface),
            ],
          ),
          border: Border.all(color: color.withValues(alpha: 0.38)),
        ),
        child: compact
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(height: 6),
                  Text(title,
                      style: const TextStyle(
                          fontFamily: AppText.display,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Colors.white)),
                ],
              )
            : Stack(
                children: [
                  if (art != null)
                    Positioned(
                      right: -6,
                      top: 4,
                      bottom: 4,
                      width: 92,
                      child: art!,
                    ),
                  Padding(
                    padding: const EdgeInsets.all(11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withValues(alpha: 0.18),
                            border: Border.all(
                                color: color.withValues(alpha: 0.55)),
                          ),
                          child: Icon(icon, color: color, size: 19),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontFamily: AppText.display,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: Colors.white)),
                            if (subtitle != null)
                              Text(subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontFamily: AppText.body,
                                      fontSize: 10,
                                      color: AppColors.textMid)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
