import 'package:flutter/material.dart';

import '../domain/access.dart';
import 'master/master_ui.dart';
import 'vinii_theme.dart';

/// A vendor-panel section that is in the design's sidebar but has no
/// screens designed yet (owner decision, 2026-09-30). Its page says so plainly;
/// it shows no figures and saves nothing.
class ComingSoonSection {
  const ComingSoonSection({
    required this.title,
    required this.icon,
    required this.summary,
    this.planned = const [],
    this.meanwhile,
  });

  final String title;
  final IconData icon;

  /// One line on what the section is for.
  final String summary;

  /// Its sub-pages, where the design already names them.
  final List<String> planned;

  /// Where the nearest working feature is today, if there is one.
  final String? meanwhile;
}

/// Keyed by screen id (lib/domain/access.dart): the sections the design
/// names but has not drawn yet.
const comingSoonSections = <String, ComingSoonSection>{
  Screens.reports: ComingSoonSection(
    title: 'Reports',
    icon: Icons.bar_chart_outlined,
    summary: 'Sales, item, payment and staff reports for your restaurant.',
    meanwhile: "Today's sales, payments and kitchen figures are on the "
        'Dashboard; payments and cash flow are in Finance.',
  ),
  Screens.pageBuilder: ComingSoonSection(
    title: 'Page Builder',
    icon: Icons.web_outlined,
    summary: "Build and publish your restaurant's ordering app.",
    planned: [
      'App Overview',
      'App Builder',
      'Content',
      'Appearance',
      'Preview',
      'Publish',
      'Subscription',
    ],
  ),
  Screens.support: ComingSoonSection(
    title: 'Support',
    icon: Icons.headset_mic_outlined,
    summary: 'Help articles and contact with the Proviyaa team.',
  ),
};

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.section});

  final ComingSoonSection section;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: MasterStyle.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MasterPageHeader(
            title: section.title,
            subtitle: section.summary,
            titleTrailing:
                const MasterStatusPill('Coming soon', tone: PillTone.gray),
          ),
          MasterCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: ViniiColors.successPillBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(section.icon,
                      size: 26, color: ViniiColors.emeraldText),
                ),
                const SizedBox(height: 16),
                const Text('This section is not built yet',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'It is in the design and will be built when its screens are '
                  'ready. Nothing here is saved yet.',
                  style: MasterStyle.subtitle,
                ),
                if (section.planned.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('PLANNED PAGES',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: Colors.grey)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in section.planned)
                        MasterStatusPill(p, tone: PillTone.gray),
                    ],
                  ),
                ],
                if (section.meanwhile != null) ...[
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: ViniiColors.emeraldText),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Meanwhile: ${section.meanwhile}',
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
