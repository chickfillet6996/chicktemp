import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/batch_store.dart';
import '../widgets/splash_background.dart';

class CreateBatchScreen extends StatefulWidget {
  final BatchItem? batch;
  final bool isEditing;

  const CreateBatchScreen({
    super.key,
    this.batch,
    this.isEditing = false,
  });

  @override
  State<CreateBatchScreen> createState() => _CreateBatchScreenState();
}

class _CreateBatchScreenState extends State<CreateBatchScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _batchNameController;
  late final TextEditingController _chickensController;
  late DateTime _selectedDate;

  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    final initialBatch = widget.batch;
    _batchNameController = TextEditingController(
      text: initialBatch?.name ?? _nextBroilerBatchName(),
    );
    _chickensController = TextEditingController(
      text: _extractChickenCount(initialBatch?.birdsLabel) ?? '500',
    );
    _selectedDate = initialBatch != null
        ? _parseStartedAtDate(initialBatch.startedAt)
        : DateTime.now();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _batchNameController.dispose();
    _chickensController.dispose();
    super.dispose();
  }

  String? _extractChickenCount(String? birdsLabel) {
    if (birdsLabel == null || birdsLabel.trim().isEmpty) {
      return null;
    }

    return birdsLabel.trim().split(' ').first;
  }

  DateTime _parseStartedAtDate(String startedAt) {
    final rawDate = startedAt.replaceFirst(RegExp(r'^Started:\s*'), '').trim();
    final formats = <DateFormat>[
      DateFormat('MMMM d, yyyy'),
      DateFormat('MMM d, yyyy'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('MM/dd/yyyy'),
    ];

    for (final format in formats) {
      try {
        return format.parseStrict(rawDate);
      } catch (_) {
        continue;
      }
    }

    return DateTime.now();
  }

  String _formatStartedAt(DateTime date) {
    return 'Started: ${DateFormat('MMMM d, yyyy').format(date)}';
  }

  String _nextBroilerBatchName() {
    final existingNumbers = BatchStore.instance.batches
        .map((batch) => RegExp(r'^Broiler Batch (\d+)$').firstMatch(batch.name))
        .where((match) => match != null)
        .map((match) => int.tryParse(match!.group(1) ?? ''))
        .whereType<int>()
        .toList();

    final nextNumber = existingNumbers.isEmpty ? 1 : existingNumbers.reduce((a, b) => a > b ? a : b) + 1;
    return 'Broiler Batch $nextNumber';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF11A64A),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF172033),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.isEditing || widget.batch != null;
    return Scaffold(
      body: SplashBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Container(
                        constraints: const BoxConstraints(maxWidth: 320),
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7FCF7),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFD4F0DA)),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1E7D32).withOpacity(0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(11),
                                child: Image.asset(
                                  'assets/images/chicklogo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              isEditing ? 'Edit Batch' : 'Create New Batch',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF172033),
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isEditing
                                  ? 'Update flock details'
                                  : 'Enter new flock details',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B87A6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 22),
                            _FieldLabel('BATCH NAME'),
                            const SizedBox(height: 8),
                            _InputField(
                              controller: _batchNameController,
                              hintText: 'Broiler Batch 1',
                            ),
                            const SizedBox(height: 14),
                            _FieldLabel('START DATE'),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _pickDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFD),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFDDE6EE)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 18,
                                      color: Color(0xFFB0BCCB),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        DateFormat('dd/MM/yyyy').format(_selectedDate),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF172033),
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.calendar_month_outlined,
                                      size: 18,
                                      color: Color(0xFF172033),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FieldLabel('TOTAL CHICKENS'),
                            const SizedBox(height: 8),
                            _InputField(
                              controller: _chickensController,
                              hintText: '500',
                              prefixIcon: Icons.groups_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: () {
                                  final name = _batchNameController.text.trim().isEmpty
                                      ? 'New Batch'
                                      : _batchNameController.text.trim();
                                  final chickens = _chickensController.text.trim().isEmpty
                                      ? '0'
                                      : _chickensController.text.trim();

                                  Navigator.of(context).pop(
                                    widget.batch?.copyWith(
                                          name: name,
                                          startedAt: _formatStartedAt(_selectedDate),
                                          birdsLabel: '$chickens Birds',
                                        ) ??
                                        BatchItem(
                                          name: name,
                                          status: 'ACTIVE',
                                          startedAt: _formatStartedAt(_selectedDate),
                                          dayLabel: 'Day 1 / 45',
                                          birdsLabel: '$chickens Birds',
                                        ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF11A64A),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      isEditing ? 'Save Changes' : 'Save / Create Batch',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.check_circle_outline_rounded, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2B3D57),
                                  side: const BorderSide(
                                    color: Color(0xFFD7E0EA),
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF5F6F84),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _InputField({
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE6EE)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF172033),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFFB0BCCB),
            fontSize: 14,
          ),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: const Color(0xFFB0BCCB), size: 20)
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
        ),
      ),
    );
  }
}
