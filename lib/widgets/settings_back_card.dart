import 'package:flutter/material.dart';

class SettingsBackCard extends StatefulWidget {
  final VoidCallback onTap;

  const SettingsBackCard({
    super.key,
    required this.onTap,
  });

  @override
  State<SettingsBackCard> createState() => _SettingsBackCardState();
}

class _SettingsBackCardState extends State<SettingsBackCard> {
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
        : const Color(0xFF41536D);

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: _setHighlighted,
          onHighlightChanged: _setHighlighted,
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFF0BB13F).withOpacity(0.14),
          highlightColor: const Color(0xFF0BB13F).withOpacity(0.10),
          hoverColor: const Color(0xFF0BB13F).withOpacity(0.08),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _isHighlighted
                  ? const Color(0xFFEAFBF0)
                  : Colors.white.withOpacity(0.78),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isHighlighted
                    ? const Color(0xFF9FE4B2)
                    : const Color(0xFFE1E8E0),
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isHighlighted
                          ? const Color(0xFF0BB13F)
                          : Colors.black)
                      .withOpacity(_isHighlighted ? 0.10 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_rounded,
                  color: foreground,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  'Back',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
