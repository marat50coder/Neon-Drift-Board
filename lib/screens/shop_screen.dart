import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/audio.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../game/sprites.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_background.dart';
import '../widgets/ui_kit.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    return Scaffold(
      body: NeonBackground(
        accent: AppColors.gold,
        accent2: AppColors.magenta,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: TopBar(title: 'Market', accent: AppColors.gold)),
                    CreditChip(credits: gs.credits),
                  ],
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.only(left: 58),
                  child: Text('Spend credits earned from deliveries',
                      style: TextStyle(
                          fontFamily: AppText.body,
                          fontSize: 13,
                          color: AppColors.textMid)),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      _shelf(context, gs, 'Hoverboards', 'board',
                          Catalog.boards, Sprites.boards, AppColors.cyan),
                      _shelf(context, gs, 'Energy Spheres', 'sphere',
                          Catalog.spheres, Sprites.spheres, AppColors.magenta),
                      _shelf(context, gs, 'Trails', 'trail', Catalog.trails,
                          Sprites.trails, AppColors.purple),
              _shelf(context, gs, 'Turbo FX', 'turbo', Catalog.turbos,
                  Sprites.turbo, AppColors.pink),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _shelf(BuildContext context, GameState gs, String title, String kind,
      List<CosmeticItem> items, SheetSpec sheet, Color accent) {
    final locked = items.where((e) => !gs.owns(kind, e.id)).toList();
    final shelfItems = locked.isEmpty ? items : locked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 6),
          child: Row(
            children: [
              Container(width: 4, height: 16, color: accent),
              const SizedBox(width: 8),
              Text(title.toUpperCase(),
                  style: const TextStyle(
                      fontFamily: AppText.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 1.2,
                      color: Colors.white)),
              const Spacer(),
              if (locked.isEmpty)
                const Text('ALL OWNED',
                    style: TextStyle(
                        fontFamily: AppText.body,
                        fontSize: 11,
                        color: AppColors.green)),
            ],
          ),
        ),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shelfItems.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final item = shelfItems[i];
              final owned = gs.owns(kind, item.id);
              return Container(
                width: 148,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                      color: AppColors.rarity(item.rarity)
                          .withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SpriteView(sheet: sheet, index: item.spriteIndex),
                    ),
                    Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: AppText.body,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Colors.white)),
                    const SizedBox(height: 6),
                    owned
                        ? const Text('OWNED',
                            style: TextStyle(
                                fontFamily: AppText.display,
                                fontSize: 11,
                                color: AppColors.green))
                        : GestureDetector(
                            onTap: () {
                              final ok = gs.buy(kind, item.id, item.price);
                              if (ok) {
                                Audio.I.play('crystal');
                              } else {
                                Audio.I.play('hit');
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Need ${item.price} credits'),
                                        backgroundColor: AppColors.surfaceHigh,
                                        behavior: SnackBarBehavior.floating));
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: const LinearGradient(
                                    colors: AppColors.goldGradient),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.paid_rounded,
                                        size: 14, color: Colors.black),
                                    const SizedBox(width: 4),
                                    Text('${item.price}',
                                        maxLines: 1,
                                        softWrap: false,
                                        style: const TextStyle(
                                            fontFamily: AppText.display,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: Colors.black)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
