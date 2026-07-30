/// Onboarding, shown once on first run and reachable from the toolbar.
///
/// Futoshiki needs this badly: almost nobody has seen one, and the arrows
/// between cells are meaningless until explained.
library;

import 'package:flutter/material.dart';
import '../services/settings.dart';

class HowToPlayScreen extends StatelessWidget {
  final Settings settings;
  const HowToPlayScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final fs = settings.fontScale;
    final scheme = Theme.of(context).colorScheme;

    Widget step(String icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(icon, style: TextStyle(fontSize: 28 * fs)),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 18.5 * fs, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(body,
                        style: TextStyle(fontSize: 16.5 * fs, height: 1.45)),
                  ],
                ),
              ),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('How to play')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          children: [
            Text('The goal',
                style:
                    TextStyle(fontSize: 21 * fs, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              'Fill the grid so every row and every column contains each '
              'number exactly once. On a 5×5 grid you use 1 to 5.',
              style: TextStyle(fontSize: 17 * fs, height: 1.45),
            ),
            const SizedBox(height: 22),
            step('↔️', 'Each row',
                'Every row uses each number once — no repeats.'),
            step('↕️', 'Each column',
                'Every column uses each number once — no repeats.'),
            step('❯', 'The arrows',
                'An arrow between two squares points at the SMALLER number. '
                'So 4 ❯ 2 is correct, because the arrow opens toward the 4.'),
            const Divider(height: 32),
            Text('Helpful things',
                style:
                    TextStyle(fontSize: 21 * fs, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            step('👆', 'Tap a square, then a number',
                'Tap any empty square to select it, then tap a number below.'),
            step('✏️', 'Notes',
                'Turn on Notes to pencil in small maybe-numbers, then turn it '
                'off to enter a real answer.'),
            step('💡', 'Hint',
                'Stuck? A hint fills one square and explains why that number '
                'is the only one that fits.'),
            step('🕒', 'No time limit',
                'There is no countdown and nothing to lose.'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Good first move: find a chain of arrows. On a 5×5 grid, three '
                'arrows in a row like a ❯ b ❯ c means the first square must be '
                'at least 3, and the last at most 3.',
                style: TextStyle(fontSize: 16 * fs, height: 1.45),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 68,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child:
                    Text('Start playing', style: TextStyle(fontSize: 20 * fs)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
