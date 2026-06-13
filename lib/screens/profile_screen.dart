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
import '../widgets/settings_overlay_sheet.dart';
import '../widgets/user_avatar_content.dart';

class ProfileScreen extends StatelessWidget {
  final String displayName;
  final String email;
  final String phone;
  final String profilePhotoBase64;

  const ProfileScreen({
    super.key,
    this.displayName = 'Farm Manager',
    this.email = 'manager@chicktemp.app',
    this.phone = '+1 234 567 8900',
    this.profilePhotoBase64 = '',
  });

  static Future<void> show(
    BuildContext context, {
    String? displayName,
    String? email,
    String? phone,
  }) {
    final user = AuthStore.instance.currentUser;
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          displayName: displayName ?? user?.fullName ?? 'Farm Manager',
          email: email ?? user?.emailAddress ?? 'manager@chicktemp.app',
          phone:
              phone ??
              (user?.phoneNumber.isNotEmpty == true
                  ? user!.phoneNumber
                  : 'No phone number'),
          profilePhotoBase64: user?.profilePhotoBase64 ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileSheetBody(
      initialDisplayName: displayName,
      initialEmail: email,
      initialPhone: phone,
      initialProfilePhotoBase64: profilePhotoBase64,
    );
  }
}

class _ProfileSheetBody extends StatefulWidget {
  final String initialDisplayName;
  final String initialEmail;
  final String initialPhone;
  final String initialProfilePhotoBase64;

  const _ProfileSheetBody({
    required this.initialDisplayName,
    required this.initialEmail,
    required this.initialPhone,
    required this.initialProfilePhotoBase64,
  });

  @override
  State<_ProfileSheetBody> createState() => _ProfileSheetBodyState();
}

class _ProfileSheetBodyState extends State<_ProfileSheetBody> {
  @override
  Widget build(BuildContext context) {
    final user = AuthStore.instance.currentUser;
    final displayName = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : widget.initialDisplayName;
    final email = user?.emailAddress.isNotEmpty == true
        ? user!.emailAddress
        : widget.initialEmail;
    final phone = user?.phoneNumber.isNotEmpty == true
        ? user!.phoneNumber
        : widget.initialPhone;
    final profilePhotoBase64 = user?.profilePhotoBase64.isNotEmpty == true
        ? user!.profilePhotoBase64
        : widget.initialProfilePhotoBase64;
    final initials = AuthStore.buildInitials(displayName);

    return SettingsOverlaySheet(
      headerBand: const _HeaderBand(),
      backgroundPainter: const _EmptyBackgroundPainter(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _ProfileIdentityCard(
            displayName: displayName,
            email: email,
            phone: phone,
            initials: initials,
            profilePhotoBase64: profilePhotoBase64,
          ),
          const SizedBox(height: 18),
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

class _ProfileIdentityCard extends StatelessWidget {
  final String displayName;
  final String email;
  final String phone;
  final String initials;
  final String profilePhotoBase64;

  const _ProfileIdentityCard({
    required this.displayName,
    required this.email,
    required this.phone,
    required this.initials,
    required this.profilePhotoBase64,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3E9E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Color(0xFF1FA34A),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: ClipOval(
              child: SizedBox(
                width: 50,
                height: 50,
                child: UserAvatarContent(
                  initials: initials,
                  profilePhotoBase64: profilePhotoBase64,
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  borderRadius: 999,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'ACCOUNT',
                  style: TextStyle(
                    color: Color(0xFF7A8797),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  phone,
                  style: const TextStyle(
                    color: Color(0xFF8A94A6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

class _MenuRow extends StatelessWidget {
  final _MenuItemData item;

  const _MenuRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF12B157).withOpacity(0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(item.icon, size: 18, color: const Color(0xFF08B04F)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  color: Color(0xFF3F4D63),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFCAD1DC),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.74),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE7ECE5)),
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
