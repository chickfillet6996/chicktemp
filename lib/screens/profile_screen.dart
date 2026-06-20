import 'package:flutter/material.dart';

import '../models/auth_store.dart';
import 'aboutapp_screen.dart';
import 'alertnotif_screen.dart';
import 'changepass_screen.dart';
import 'contactsupp_screen.dart';
import 'editprofile_screen.dart';
import 'helpcenter_screen.dart';
import 'logout_screen.dart';
import 'poilicies_screen.dart';
import '../widgets/settings_back_card.dart';
import '../widgets/settings_overlay_sheet.dart';
import '../widgets/user_avatar_content.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const _ProfileSheetBody();
}

class _ProfileSheetBody extends StatefulWidget {
  const _ProfileSheetBody();

  @override
  State<_ProfileSheetBody> createState() => _ProfileSheetBodyState();
}

class _ProfileSheetBodyState extends State<_ProfileSheetBody> {
  @override
  Widget build(BuildContext context) {
    return SettingsOverlaySheet(
      headerBand: const _HeaderBand(),
      backgroundPainter: const _EmptyBackgroundPainter(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _BackRow(onBack: () => Navigator.of(context).pop()),
          const SizedBox(height: 14),
          const _SectionTitle('ACCOUNT PREFERENCES'),
          const SizedBox(height: 10),
          _MenuList(
            items: [
              _MenuItemData(
                icon: Icons.person_outline_rounded,
                label: 'Edit Profile',
                onTap: () async {
                  await EditProfileScreen.show(context);
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
              _MenuItemData(
                icon: Icons.key_outlined,
                label: 'Change Password',
                onTap: () => ChangePasswordScreen.show(context),
              ),
              _MenuItemData(
                icon: Icons.notifications_none_rounded,
                label: 'Alerts & Notifications',
                onTap: () => AlertNotificationsScreen.show(context),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const _SectionTitle('SYSTEM & SUPPORT'),
          const SizedBox(height: 10),
          _MenuList(
            items: [
              _MenuItemData(
                icon: Icons.help_outline_rounded,
                label: 'Help Center',
                onTap: () => HelpCenterScreen.show(context),
              ),
              _MenuItemData(
                icon: Icons.info_outline_rounded,
                label: 'About App',
                onTap: () => AboutAppScreen.show(context),
              ),
              _MenuItemData(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Contact Support',
                onTap: () => ContactSupportScreen.show(context),
              ),
              _MenuItemData(
                icon: Icons.assignment_outlined,
                label: 'Policies and Procedures',
                onTap: () => PoliciesScreen.show(context),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _LogoutButton(
            onTap: () {
              LogoutScreen.show(context);
            },
          ),
        ],
      ),
    );
  }
}

class _MenuItemData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItemData({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _BackRow extends StatelessWidget {
  final VoidCallback onBack;

  const _BackRow({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SettingsBackCard(onTap: onBack);
  }
}

class _MenuList extends StatelessWidget {
  final List<_MenuItemData> items;

  const _MenuList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items) ...[
          _MenuRow(item: item),
          const SizedBox(height: 12),
        ],
      ]..removeLast(),
    );
  }
}

class _MenuRow extends StatefulWidget {
  final _MenuItemData item;

  const _MenuRow({required this.item});

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _isHighlighted = false;

  void _setHighlighted(bool value) {
    if (_isHighlighted == value) {
      return;
    }
    setState(() => _isHighlighted = value);
  }

  @override
  Widget build(BuildContext context) {
    final foreground = _isHighlighted
        ? const Color(0xFF0B8F3D)
        : const Color(0xFF3F4D63);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.item.onTap,
        onHover: _setHighlighted,
        onHighlightChanged: _setHighlighted,
        borderRadius: BorderRadius.circular(18),
        splashColor: const Color(0xFF0BB13F).withOpacity(0.14),
        highlightColor: const Color(0xFF0BB13F).withOpacity(0.10),
        hoverColor: const Color(0xFF0BB13F).withOpacity(0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: _isHighlighted
                ? const Color(0xFFEAFBF0)
                : Colors.white.withOpacity(0.36),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isHighlighted
                  ? const Color(0xFF9FE4B2)
                  : Colors.white.withOpacity(0.34),
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _isHighlighted
                      ? const Color(0xFFDDF8E5)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF12B157).withOpacity(
                        _isHighlighted ? 0.18 : 0.10,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(
                  widget.item.icon,
                  size: 18,
                  color: const Color(0xFF08B04F),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.item.label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _isHighlighted
                    ? const Color(0xFF0B8F3D)
                    : const Color(0xFFCAD1DC),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatefulWidget {
  final VoidCallback onTap;

  const _LogoutButton({required this.onTap});

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _isHighlighted = false;

  void _setHighlighted(bool value) {
    if (_isHighlighted == value) {
      return;
    }
    setState(() => _isHighlighted = value);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onHover: _setHighlighted,
        onHighlightChanged: _setHighlighted,
        borderRadius: BorderRadius.circular(18),
        splashColor: const Color(0xFFDB5A5A).withOpacity(0.14),
        highlightColor: const Color(0xFFDB5A5A).withOpacity(0.10),
        hoverColor: const Color(0xFFDB5A5A).withOpacity(0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: _isHighlighted
                ? const Color(0xFFFFF1F1)
                : Colors.white.withOpacity(0.74),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isHighlighted
                  ? const Color(0xFFFFCBCB)
                  : const Color(0xFFE7ECE5),
            ),
          ),
          child: Row(
            children: const [
              Icon(Icons.logout_rounded, color: Color(0xFFDB5A5A), size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Log Out',
                  style: TextStyle(
                    color: Color(0xFFB74848),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFE1B3B3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFA4ACBA),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.35,
      ),
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
          crossAxisAlignment: CrossAxisAlignment.center,
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
                    'Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Account settings and support',
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

class _EmptyBackgroundPainter extends CustomPainter {
  const _EmptyBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
