import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/features/revenue/controllers/revenue_controller.dart';
import 'package:m_admin/features/revenue/models/revenue_income_record.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

/// Dialog to enter or edit a manual revenue / income transaction.
class AddRevenueDialog extends StatefulWidget {
  const AddRevenueDialog({
    super.key,
    required this.controller,
    this.recordToEdit,
  });

  final RevenueController controller;
  final RevenueIncomeRecord? recordToEdit;

  static Future<void> show(
    BuildContext context,
    RevenueController controller, {
    RevenueIncomeRecord? recordToEdit,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AddRevenueDialog(
        controller: controller,
        recordToEdit: recordToEdit,
      ),
    );
  }

  @override
  State<AddRevenueDialog> createState() => _AddRevenueDialogState();
}

class _AddRevenueDialogState extends State<AddRevenueDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  late String _selectedMethod;
  late DateTime _selectedDate;
  bool _isSubmitting = false;

  static const _methods = [
    'telebirr',
    'cbe',
    'abyssinia',
    'other',
  ];

  static const _titlePresets = [
    'Direct Bank Deposit',
    'Cash Subscription',
    'School Bulk License',
    'Partner Sponsorship',
    'Offline Student Registration',
    'Manual Transfer',
  ];

  static const _quickAmounts = [200, 500, 1000, 2500, 5000, 10000];

  static String _methodChipLabel(String m) {
    switch (m.toLowerCase()) {
      case 'telebirr':
        return 'Telebirr';
      case 'cbe':
        return 'CBE';
      case 'abyssinia':
        return 'Abyssinia';
      case 'other':
      default:
        return 'Other';
    }
  }

  @override
  void initState() {
    super.initState();
    final edit = widget.recordToEdit;
    _amountCtrl = TextEditingController(
      text: edit != null ? edit.amount.toStringAsFixed(0) : '200',
    );
    _titleCtrl = TextEditingController(text: edit?.title ?? '');
    _notesCtrl = TextEditingController(text: edit?.notes ?? '');
    final editMethod = edit?.paymentMethod.toLowerCase() ?? 'telebirr';
    _selectedMethod = _methods.contains(editMethod) ? editMethod : 'other';
    _selectedDate = edit?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final dark = AppHelperFunctions.isDark(context);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023, 1, 1),
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.success,
              onPrimary: Colors.white,
              surface: dark ? AppColors.darkCard : Colors.white,
              onSurface: dark ? Colors.white : Colors.black,
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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amt <= 0) {
      Get.snackbar(
        'Invalid Amount',
        'Amount must be greater than 0',
        backgroundColor: AppColors.error.withValues(alpha: 0.15),
        colorText: AppColors.error,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final edit = widget.recordToEdit;
      if (edit != null) {
        final updated = edit.copyWith(
          title: _titleCtrl.text.trim(),
          amount: amt,
          paymentMethod: _selectedMethod,
          date: _selectedDate,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
        await widget.controller.updateIncomeRecord(updated);
      } else {
        await widget.controller.addIncomeRecord(
          title: _titleCtrl.text.trim(),
          amount: amt,
          paymentMethod: _selectedMethod,
          date: _selectedDate,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        try {
          Get.snackbar(
            edit != null ? 'Income Updated' : 'Revenue Added',
            'Successfully logged ETB ${NumberFormat('#,##0.00').format(amt)} ($selectedMethodLabel)',
            backgroundColor: AppColors.success.withValues(alpha: 0.15),
            colorText: AppColors.success,
            snackPosition: SnackPosition.BOTTOM,
          );
        } catch (_) {}
      }
    } catch (e) {
      try {
        Get.snackbar(
          'Error',
          'Failed to save revenue record: $e',
          backgroundColor: AppColors.error.withValues(alpha: 0.15),
          colorText: AppColors.error,
          snackPosition: SnackPosition.BOTTOM,
        );
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String get selectedMethodLabel =>
      RevenueIncomeRecord.getMethodLabel(_selectedMethod);

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final isEditing = widget.recordToEdit != null;
    final media = MediaQuery.sizeOf(context);
    final maxDialogWidth = (media.width - 32).clamp(280.0, 500.0);
    final maxDialogHeight = (media.height - 48).clamp(320.0, 680.0);

    return Dialog(
      backgroundColor: dark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxDialogWidth,
          maxHeight: maxDialogHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Iconsax.wallet_add_copy,
                        size: 18,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Revenue / Income' : 'Record Revenue / Income',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: dark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Add offline, cash, or direct manual income to your revenue stats',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Get.back(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const Divider(height: 18),

                // ── Scrollable Body ─────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Payment Method Selector
                        const Text(
                          'Payment Method *',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: _methods.map((m) {
                              final isSel = _selectedMethod == m;
                              final color = RevenueIncomeRecord.getMethodColor(m);
                              final icon = RevenueIncomeRecord.getMethodIcon(m);
                              final label = _methodChipLabel(m);

                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: InkWell(
                                  onTap: () => setState(() => _selectedMethod = m),
                                  borderRadius: BorderRadius.circular(8),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isSel
                                          ? color.withValues(alpha: 0.15)
                                          : (dark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9)),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSel ? color : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
                                        width: isSel ? 1.4 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(icon, size: 14, color: isSel ? color : AppColors.textSecondary),
                                        const SizedBox(width: 6),
                                        Text(
                                          label,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                            color: isSel ? color : (dark ? Colors.white70 : Colors.black87),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 2. Amount Input
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Amount (ETB) *',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Wrap(
                              spacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text(
                                  'Quick:',
                                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                ),
                                ..._quickAmounts.take(4).map((amt) {
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(4),
                                    onTap: () {
                                      _amountCtrl.text = amt.toString();
                                      _amountCtrl.selection = TextSelection.fromPosition(
                                        TextPosition(offset: _amountCtrl.text.length),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$amt',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please enter an amount';
                            final n = double.tryParse(v.trim());
                            if (n == null || n <= 0) return 'Must be a positive number';
                            return null;
                          },
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            prefixIcon: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              child: Text(
                                'ETB',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                            hintText: 'e.g. 1500.00',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. Title / Source
                        const Text(
                          'Source / Description *',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _titleCtrl,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a description' : null,
                          style: const TextStyle(fontSize: 12.5),
                          decoration: InputDecoration(
                            hintText: 'e.g. Direct CBE transfer, School bulk license',
                            prefixIcon: const Icon(Iconsax.edit_copy, size: 16),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: _titlePresets.map((preset) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  label: Text(preset, style: const TextStyle(fontSize: 10.5)),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                  onPressed: () {
                                    _titleCtrl.text = preset;
                                    _titleCtrl.selection = TextSelection.fromPosition(
                                      TextPosition(offset: preset.length),
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 4. Date Picker
                        const Text(
                          'Date *',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                              ),
                              color: dark ? Colors.white.withValues(alpha: 0.02) : Colors.transparent,
                            ),
                            child: Row(
                              children: [
                                const Icon(Iconsax.calendar_1_copy, size: 16, color: AppColors.success),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Change',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 5. Notes (Optional)
                        const Text(
                          'Transaction Notes (Optional)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _notesCtrl,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'e.g. Reference code, student name, or offline deposit details',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Footer Actions ──────────────────────────────────────
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: _isSubmitting ? null : () => Get.back(),
                      child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded, size: 16),
                      label: Text(
                        isEditing ? 'Save Changes' : 'Record Revenue',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
