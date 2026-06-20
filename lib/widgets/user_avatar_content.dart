import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class UserAvatarContent extends StatefulWidget {
  final String initials;
  final String profilePhotoBase64;
  final TextStyle textStyle;
  final double borderRadius;

  const UserAvatarContent({
    super.key,
    required this.initials,
    required this.profilePhotoBase64,
    required this.textStyle,
    this.borderRadius = 14,
  });

  @override
  State<UserAvatarContent> createState() => _UserAvatarContentState();
}

class _UserAvatarContentState extends State<UserAvatarContent> {
  static final Map<String, Uint8List> _bytesCache = <String, Uint8List>{};

  ImageProvider<Object>? _imageProvider;

  @override
  void initState() {
    super.initState();
    _refreshImageProvider();
  }

  @override
  void didUpdateWidget(covariant UserAvatarContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profilePhotoBase64 != widget.profilePhotoBase64) {
      _refreshImageProvider();
    }
  }

  void _refreshImageProvider() {
    final imageBytes = _decodeProfilePhoto(widget.profilePhotoBase64);
    if (imageBytes == null) {
      _imageProvider = null;
      return;
    }

    _imageProvider = MemoryImage(imageBytes);
  }

  @override
  Widget build(BuildContext context) {
    if (_imageProvider == null) {
      return Text(widget.initials, style: widget.textStyle);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox.expand(
        child: Image(
          image: _imageProvider!,
          fit: BoxFit.cover,
          alignment: const Alignment(0, 0.35),
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
} 

Uint8List? _decodeProfilePhoto(String? profilePhotoBase64) {
  final raw = profilePhotoBase64?.trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }

  try {
    final cached = _UserAvatarContentState._bytesCache[raw];
    if (cached != null) {
      return cached;
    }

    final decoded = base64Decode(raw);
    _UserAvatarContentState._bytesCache[raw] = decoded;
    return decoded;
  } on FormatException {
    return null;
  }
}
