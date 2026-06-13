import 'package:flutter/material.dart';

import '../models/auth_store.dart';
import '../widgets/settings_overlay_sheet.dart';
import '../widgets/user_avatar_content.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const AboutAppScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return SettingsOverlaySheet(
      headerBand: const _HeaderBand(),
      backgroundPainter: const _LeafLinePainter(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        children: [
          _TopBar(onBack: () => Navigator.of(context).pop()),
          const Divider(height: 30, color: Color(0xFFE7EBE6)),
          const SizedBox(height: 10),
          const _AboutHeroCard(),
          const SizedBox(height: 18),
          const _AboutDetailsCard(),
          const SizedBox(height: 26),
          const _InfoGroup(
            title: 'DEVELOPERS',
            lines: [
              'Aaron Asuncion',
              'Kurt Yu',
              'Kyle Reodique',
              'Dustin Juri',
            ],
          ),
          const SizedBox(height: 18),
          const _InfoGroup(
            title: 'SUPPORT EMAIL',
            lines: ['chicktfillet6996@gmail.com'],
          ),
        ],
      ),
    );
  }
}

class _AboutHeroCard extends StatelessWidget {
  const _AboutHeroCard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 110,
        height: 110,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE7ECE5)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0BB13F).withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            'assets/images/chicklogo.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
  }
}

class _AboutDetailsCard extends StatelessWidget {
  const _AboutDetailsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7ECE5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        children: [
          Text(
            'ChickTemp',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
            ),
          ),
          SizedBox(height: 14),
          Text(
            'The smartest IoT-based poultry environmental control application. Built for efficiency, designed for farmers.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF41536D),
                  size: 20,
                ),
                SizedBox(width: 6),
                Text(
                  'Back',
                  style: TextStyle(
                    color: Color(0xFF41536D),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoGroup extends StatelessWidget {
  final String title;
  final List<String> lines;

  const _InfoGroup({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFFA4ACBA),
            letterSpacing: 0.35,
          ),
        ),
        const SizedBox(height: 12),
        ...lines.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              line,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: title == 'SUPPORT EMAIL'
                    ? FontWeight.w600
                    : FontWeight.w500,
                color: title == 'SUPPORT EMAIL'
                    ? const Color(0xFF8D97B4)
                    : const Color(0xFF344054),
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderBand extends StatelessWidget {
  const _HeaderBand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1F6F2F), Color(0xFF47A34A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.white70),
                      SizedBox(width: 8),
                      Text(
                        'CHICKTEMP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'About App',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Learn more about ChickTemp and its features',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              alignment: Alignment.center,
              child: UserAvatarContent(
                initials: AuthStore.instance.currentUserInitials,
                profilePhotoBase64:
                    AuthStore.instance.currentUser?.profilePhotoBase64 ?? '',
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeafLinePainter extends CustomPainter {
  const _LeafLinePainter();

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
