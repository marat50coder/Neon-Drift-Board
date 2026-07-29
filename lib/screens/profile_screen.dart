import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../core/audio.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../game/sprites.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_background.dart';
import '../widgets/ui_kit.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final x = await _picker.pickImage(
        source: source,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 88,
      );
      if (x != null) {
        final dir = await getApplicationDocumentsDirectory();
        final dest =
            '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.png';
        await File(x.path).copy(dest);
        if (mounted) context.read<GameState>().setAvatar(dest);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not load image: $e'),
          backgroundColor: AppColors.surfaceHigh,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _avatarSheet() {
    Audio.I.play('open');
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('PROFILE PHOTO',
                  style: TextStyle(
                      fontFamily: AppText.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 1.5,
                      color: AppColors.textMid)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _sheetBtn(Icons.photo_camera_rounded, 'Camera', () {
                      Navigator.pop(context);
                      _pick(ImageSource.camera);
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _sheetBtn(Icons.photo_library_rounded, 'Gallery', () {
                      Navigator.pop(context);
                      _pick(ImageSource.gallery);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (context.read<GameState>().avatarPath != null)
                GhostButton(
                  label: 'Remove photo',
                  icon: Icons.delete_outline_rounded,
                  color: AppColors.danger,
                  onTap: () {
                    Navigator.pop(context);
                    context.read<GameState>().setAvatar(null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetBtn(IconData ic, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: AppColors.cyan.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(ic, color: AppColors.cyan, size: 30),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontFamily: AppText.body,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }

  void _editName() {
    final gs = context.read<GameState>();
    final ctrl = TextEditingController(text: gs.playerName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rider Name',
            style: TextStyle(fontFamily: AppText.display, color: Colors.white)),
        content: TextField(
          controller: ctrl,
          maxLength: 16,
          style: const TextStyle(color: Colors.white, fontFamily: AppText.body),
          decoration: InputDecoration(
            hintText: 'Enter name',
            hintStyle: const TextStyle(color: AppColors.textLow),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppColors.cyan.withValues(alpha: 0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cyan),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMid))),
          TextButton(
              onPressed: () {
                gs.setName(ctrl.text);
                Navigator.pop(context);
              },
              child: const Text('Save',
                  style: TextStyle(color: AppColors.cyan))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final board = Catalog.boardById(gs.board);
    final level = 1 + (gs.stat('deliveries') ~/ 5);
    final avatar = gs.avatarPath;
    final hasAvatar = avatar != null && File(avatar).existsSync();

    return Scaffold(
      body: NeonBackground(
        accent: AppColors.cyan,
        accent2: AppColors.magenta,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TopBar(title: 'Profile', accent: AppColors.cyan),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        GlassCard(
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: _avatarSheet,
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 96,
                                      height: 96,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                            colors: AppColors.primaryGradient),
                                        boxShadow: [
                                          BoxShadow(
                                              color: AppColors.cyan
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 18),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(3),
                                      child: CircleAvatar(
                                        backgroundColor: AppColors.surfaceHigh,
                                        backgroundImage: hasAvatar
                                            ? FileImage(File(avatar))
                                            : null,
                                        child: hasAvatar
                                            ? null
                                            : const Icon(Icons.person_rounded,
                                                size: 46,
                                                color: AppColors.textMid),
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.magenta,
                                        ),
                                        child: _busy
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white))
                                            : const Icon(Icons.edit_rounded,
                                                size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: _editName,
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(gs.playerName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontFamily: AppText.display,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 22,
                                                    color: Colors.white)),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.edit_rounded,
                                              size: 16,
                                              color: AppColors.textMid),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        color: AppColors.cyan
                                            .withValues(alpha: 0.14),
                                      ),
                                      child: Text('LEVEL $level',
                                          style: const TextStyle(
                                              fontFamily: AppText.display,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                              color: AppColors.cyan)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        GlassCard(
                          child: Row(
                            children: [
                              SizedBox(
                                width: 90,
                                height: 70,
                                child: SpriteView(
                                    sheet: Sprites.boards,
                                    index: board.spriteIndex),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('CURRENT BOARD',
                                        style: TextStyle(
                                            fontFamily: AppText.body,
                                            fontSize: 11,
                                            letterSpacing: 1,
                                            color: AppColors.textMid)),
                                    Text(board.name,
                                        style: const TextStyle(
                                            fontFamily: AppText.display,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 17,
                                            color: Colors.white)),
                                  ],
                                ),
                              ),
                              RarityBadge(rarity: board.rarity),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _mini('Deliveries',
                                '${gs.stat('deliveries').toInt()}',
                                Icons.local_shipping_rounded),
                            const SizedBox(width: 12),
                            _mini('Best Score',
                                '${gs.stat('bestScore').toInt()}',
                                Icons.emoji_events_rounded),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _mini('Credits', '${gs.credits}',
                                Icons.paid_rounded),
                            const SizedBox(width: 12),
                            _mini('Boards',
                                '${gs.boards.length}/${Catalog.boards.length}',
                                Icons.snowboarding_rounded),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mini(String label, String value, IconData icon) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.cyan, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: AppText.display,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: Colors.white)),
                  Text(label,
                      style: const TextStyle(
                          fontFamily: AppText.body,
                          fontSize: 11,
                          color: AppColors.textMid)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
