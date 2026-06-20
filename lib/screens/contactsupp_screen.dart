import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/auth_store.dart';
import '../models/firebase_database_service.dart';
import '../widgets/settings_back_card.dart';
import '../widgets/settings_overlay_sheet.dart';
import '../widgets/user_avatar_content.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ContactSupportScreen()),
    );
  }

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  static const String _supportEmailAddress = 'chickfillet6996@gmail.com';

  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);
  bool _isSending = false;

  @override
  void dispose() {
    _httpClient.close(force: true);
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();

    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both subject and message.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = AuthStore.instance.currentUser;
    final senderName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : 'Unknown user';
    final senderEmail = user?.emailAddress.trim().isNotEmpty == true
        ? user!.emailAddress.trim()
        : 'No email provided';
    final senderPhone = user?.phoneNumber.trim().isNotEmpty == true
        ? user!.phoneNumber.trim()
        : 'No phone provided';
    final emailBody =
        '''
Support request from: $senderName
Email: $senderEmail
Phone: $senderPhone

$message
''';
    final ticketId = 'ticket_${DateTime.now().millisecondsSinceEpoch}';
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final supportTicket = <String, dynamic>{
      'ticket_id': ticketId,
      'subject': subject,
      'message': message,
      'created_at': createdAt,
      'status': 'open',
      'user_id': user?.id ?? '',
      'full_name': senderName,
      'email_address': senderEmail,
      'phone_number': senderPhone,
    };

    setState(() {
      _isSending = true;
    });

    try {
      await FirebaseDatabaseService.instance.put(
        'support_tickets/$ticketId.json',
        supportTicket,
      );

      var emailSubmitted = false;
      try {
        await _sendSupportEmail(
          subject: subject,
          senderName: senderName,
          senderEmail: senderEmail,
          senderPhone: senderPhone,
          emailBody: emailBody,
        );
        emailSubmitted = true;
      } catch (_) {
        emailSubmitted = false;
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            emailSubmitted
                ? 'Support message saved and email request submitted.'
                : 'Support message saved. Email needs setup first.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _subjectController.clear();
      _messageController.clear();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to send your message right now.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _sendSupportEmail({
    required String subject,
    required String senderName,
    required String senderEmail,
    required String senderPhone,
    required String emailBody,
  }) async {
    final request = await _httpClient.postUrl(
      Uri.https('formsubmit.co', '/ajax/$_supportEmailAddress'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
    request.write(
      jsonEncode({
        'name': senderName,
        'email': senderEmail,
        'phone': senderPhone,
        'subject': subject,
        'message': emailBody,
        '_subject': 'ChickTemp Support: $subject',
        '_captcha': 'false',
        '_template': 'table',
      }),
    );

    final response = await request.close().timeout(const Duration(seconds: 20));
    final responseBody = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const SocketException('Support email request failed.');
    }

    final decoded = jsonDecode(responseBody);
    if (decoded is Map<String, dynamic> && decoded['success'] == false) {
      throw const SocketException('Support email request was rejected.');
    }
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
          const SizedBox(height: 30),
          const _FieldLabel('Subject'),
          const SizedBox(height: 8),
          _SupportField(
            controller: _subjectController,
            hintText: 'How can we help?',
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Message'),
          const SizedBox(height: 8),
          _SupportField(
            controller: _messageController,
            hintText: 'Describe your issue...',
            maxLines: 5,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _isSending ? null : _sendMessage,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0BB13F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_outlined, size: 16),
              label: Text(
                _isSending ? 'Sending...' : 'Send Message',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
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
    return SettingsBackCard(onTap: onBack);
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF455468),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SupportField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;

  const _SupportField({
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        color: Color(0xFF172033),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFFB0B8C5),
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.55),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDCE2E9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF86D19B)),
        ),
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
                    'Contact Support',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Reach out when you need help from the team',
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
