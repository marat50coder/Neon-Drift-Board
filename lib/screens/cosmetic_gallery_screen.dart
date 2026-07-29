import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../core/audio.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../game/sprites.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_background.dart';
import '../widgets/ui_kit.dart';

enum GalleryLayout { carousel, grid, list, masterDetail }

class CosmeticGalleryScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String kind; // board | sphere | trail | turbo
  final List<CosmeticItem> items;
  final SheetSpec sheet;
  final Color accent;
  final GalleryLayout layout;

  const CosmeticGalleryScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.items,
    required this.sheet,
    required this.accent,
    required this.layout,
  });

  @override
  State<CosmeticGalleryScreen> createState() => _CosmeticGalleryScreenState();
}

class _CosmeticGalleryScreenState extends State<CosmeticGalleryScreen> {
  late PageController _page;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final gs = context.read<GameState>();
    _index = widget.items.indexWhere((e) => e.id == _selected(gs));
    if (_index < 0) _index = 0;
    _page = PageController(viewportFraction: 0.78, initialPage: _index);
  }

  String _selected(GameState gs) {
    switch (widget.kind) {
      case 'board':
        return gs.board;
      case 'sphere':
        return gs.sphere;
      case 'trail':
        return gs.trail;
      case 'turbo':
        return gs.turbo;
    }
    return '';
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _tryBuy(GameState gs, CosmeticItem item) {
    final ok = gs.buy(widget.kind, item.id, item.price);
    if (!ok) {
      _snack('Not enough credits for ${item.name}');
    } else {
      Audio.I.play('crystal');
      gs.select(widget.kind, item.id);
    }
    setState(() {});
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.surfaceHigh,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    return Scaffold(
      body: NeonBackground(
        accent: widget.accent,
        accent2: AppColors.purple,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TopBar(title: widget.title, accent: widget.accent),
                    ),
                    CreditChip(credits: gs.credits),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 58),
                  child: Text(widget.subtitle,
                      style: const TextStyle(
                          fontFamily: AppText.body,
                          fontSize: 13,
                          color: AppColors.textMid)),
                ),
                const SizedBox(height: 12),
                Expanded(child: _body(gs)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(GameState gs) {
    switch (widget.layout) {
      case GalleryLayout.carousel:
        return _carousel(gs);
      case GalleryLayout.grid:
        return _grid(gs);
      case GalleryLayout.list:
        return _list(gs);
      case GalleryLayout.masterDetail:
        return _masterDetail(gs);
    }
  }

  // ---- Carousel (boards) -------------------------------------------------
  Widget _carousel(GameState gs) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _page,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: widget.items.length,
            itemBuilder: (_, i) {
              final item = widget.items[i];
              final active = i == _index;
              final owned = gs.owns(widget.kind, item.id);
              return AnimatedScale(
                scale: active ? 1 : 0.85,
                duration: const Duration(milliseconds: 250),
                child: GlassCard(
                  tint: AppColors.rarity(item.rarity),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: RarityBadge(rarity: item.rarity),
                      ),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [
                                  AppColors.rarity(item.rarity)
                                      .withValues(alpha: 0.35),
                                  Colors.transparent,
                                ]),
                              ),
                            ),
                            SpriteView(
                                sheet: widget.sheet, index: item.spriteIndex),
                            if (!owned)
                              Positioned(
                                bottom: 6,
                                child: _lockPill(item.price),
                              ),
                          ],
                        ),
                      ),
                      Text(item.name,
                          style: const TextStyle(
                              fontFamily: AppText.display,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: Colors.white)),
                      if (item.tagline.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(item.tagline,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontFamily: AppText.body,
                                  fontSize: 13,
                                  color: AppColors.textMid)),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        SmoothPageIndicator(
          controller: _page,
          count: widget.items.length,
          effect: ExpandingDotsEffect(
            dotHeight: 7,
            dotWidth: 7,
            activeDotColor: widget.accent,
            dotColor: Colors.white24,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(width: 260, child: _action(gs, widget.items[_index])),
      ],
    );
  }

  // ---- Grid (spheres) ----------------------------------------------------
  Widget _grid(GameState gs) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.82,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: widget.items.length,
      itemBuilder: (_, i) {
        final item = widget.items[i];
        final owned = gs.owns(widget.kind, item.id);
        final selected = _selected(gs) == item.id;
        return GestureDetector(
          onTap: () {
            Audio.I.play('click');
            if (owned) {
              gs.select(widget.kind, item.id);
            } else {
              _tryBuy(gs, item);
            }
          },
          child: GlassCard(
            padding: const EdgeInsets.all(12),
            border: selected
                ? widget.accent
                : AppColors.rarity(item.rarity).withValues(alpha: 0.3),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: RarityBadge(rarity: item.rarity),
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SpriteView(sheet: widget.sheet, index: item.spriteIndex),
                      if (!owned)
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0x66000000),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                            ),
                            child: Icon(Icons.lock_rounded,
                                color: Colors.white70, size: 28),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: AppText.body,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white)),
                const SizedBox(height: 4),
                if (selected)
                  const Text('EQUIPPED',
                      style: TextStyle(
                          fontFamily: AppText.display,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          color: AppColors.cyan))
                else if (owned)
                  const Text('TAP TO EQUIP',
                      style: TextStyle(
                          fontFamily: AppText.body,
                          fontSize: 11,
                          color: AppColors.textMid))
                else
                  _priceText(item.price),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- List (trails) -----------------------------------------------------
  Widget _list(GameState gs) {
    return ListView.separated(
      itemCount: widget.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final item = widget.items[i];
        final selected = _selected(gs) == item.id;
        return GlassCard(
          padding: const EdgeInsets.all(12),
          border: selected ? widget.accent : null,
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: SpriteView(sheet: widget.sheet, index: item.spriteIndex),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: const TextStyle(
                        fontFamily: AppText.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RarityBadge(rarity: item.rarity),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _compactAction(gs, item),
            ],
          ),
        );
      },
    );
  }

  // ---- Master / detail (turbo) ------------------------------------------
  Widget _masterDetail(GameState gs) {
    final sel = widget.items.firstWhere((e) => e.id == _selected(gs),
        orElse: () => widget.items[_index]);
    final detail = _index < widget.items.length ? widget.items[_index] : sel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: GlassCard(
            tint: AppColors.rarity(detail.rarity),
            child: Column(
              children: [
                Align(
                    alignment: Alignment.topRight,
                    child: RarityBadge(rarity: detail.rarity)),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            AppColors.rarity(detail.rarity)
                                .withValues(alpha: 0.3),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                      SpriteView(
                          sheet: widget.sheet, index: detail.spriteIndex),
                    ],
                  ),
                ),
                Text(detail.name,
                    style: const TextStyle(
                        fontFamily: AppText.display,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Colors.white)),
                const SizedBox(height: 10),
                _action(gs, detail),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          flex: 4,
          child: ListView.separated(
            itemCount: widget.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final item = widget.items[i];
              final owned = gs.owns(widget.kind, item.id);
              final active = i == _index;
              return GestureDetector(
                onTap: () {
                  Audio.I.play('click');
                  setState(() => _index = i);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: active
                        ? widget.accent.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                        color: active
                            ? widget.accent
                            : Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 42,
                        height: 42,
                        child: SpriteView(
                            sheet: widget.sheet, index: item.spriteIndex),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: AppText.body,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.white)),
                      ),
                      Icon(
                        owned ? Icons.check_circle_rounded : Icons.lock_rounded,
                        size: 18,
                        color: owned ? AppColors.green : AppColors.textLow,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---- shared bits -------------------------------------------------------
  Widget _action(GameState gs, CosmeticItem item) {
    final owned = gs.owns(widget.kind, item.id);
    final selected = _selected(gs) == item.id;
    if (selected) {
      return const GhostButton(label: 'Equipped', icon: Icons.check_rounded);
    }
    if (owned) {
      return NeonButton(
        label: 'Equip',
        icon: Icons.check_rounded,
        height: 48,
        onTap: () => gs.select(widget.kind, item.id),
      );
    }
    return NeonButton(
      label: '${item.price}',
      icon: Icons.paid_rounded,
      height: 48,
      colors: AppColors.goldGradient,
      onTap: () => _tryBuy(gs, item),
    );
  }

  Widget _compactAction(GameState gs, CosmeticItem item) {
    final owned = gs.owns(widget.kind, item.id);
    final selected = _selected(gs) == item.id;
    Color color;
    IconData icon;
    String label;
    VoidCallback? onTap;
    bool filled;
    if (selected) {
      color = widget.accent;
      icon = Icons.check_rounded;
      label = 'ON';
      filled = false;
      onTap = null;
    } else if (owned) {
      color = widget.accent;
      icon = Icons.check_rounded;
      label = 'EQUIP';
      filled = false;
      onTap = () {
        Audio.I.play('click');
        gs.select(widget.kind, item.id);
      };
    } else {
      color = AppColors.gold;
      icon = Icons.paid_rounded;
      label = '${item.price}';
      filled = true;
      onTap = () => _tryBuy(gs, item);
    }
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: filled
            ? color.withValues(alpha: 0.9)
            : color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: filled ? Colors.black : color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppText.display,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.6,
              color: filled ? Colors.black : color,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }

  Widget _lockPill(int price) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.6),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_rounded, size: 14, color: AppColors.gold),
          const SizedBox(width: 5),
          Text('$price',
              style: const TextStyle(
                  fontFamily: AppText.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.gold)),
        ],
      ),
    );
  }

  Widget _priceText(int price) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.paid_rounded, size: 14, color: AppColors.gold),
        const SizedBox(width: 4),
        Text('$price',
            style: const TextStyle(
                fontFamily: AppText.display,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.gold)),
      ],
    );
  }
}
