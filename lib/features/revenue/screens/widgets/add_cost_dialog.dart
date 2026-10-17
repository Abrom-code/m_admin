import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/features/revenue/controllers/revenue_controller.dart';
import 'package:m_admin/features/revenue/models/revenue_cost_record.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

/// Dialog to enter or edit a promotion or operational cost.
class AddCostDialog extends StatefulWidget {
  const AddCostDialog({
    super.key,
    required this.controller,
    this.recordToEdit,
  });

  final RevenueController controller;
  final RevenueCostRecord? recordToEdit;

  static Future<void> show(
    BuildContext context,
    RevenueController controller, {
    RevenueCostRecord? recordToEdit,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AddCostDialog(
        controller: controller,
        recordToEdit: recordToEdit,
      ),
    );
  }

  @override
  State<AddCostDialog> createState() => _AddCostDialogState();
}

class _AddCostDialogState extends State<AddCostDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  late String _selectedCategory;
  late DateTime _selectedDate;
  bool _isSubmitting = false;

  static const _categories = [
    'promotion',
    'social_ads',
    'influencer',
    'server',
    'sms',
    'other',
  ];

  static const _titlePresets = [
    'Telegram Channel Promo',
    'TikTok Ad Campaign',
    'Influencer Sponsorship',
    'SMS Gateway / OTP',
    'Server Hosting & Cloud',
    'Graphics & Content Creation',
  ];

  static const _quickAmounts = [200, 500, 1000, 2500, 5000];

  @override
  void initState() {
    super.initState();
    final edit = widget.recordToEdit;
    _amountCtrl = TextEditingController(
      text: edit != null ? edit.amount.toStringAsFixed(0) : '',
    );
    _titleCtrl = TextEditingController(text: edit?.title ?? '');
    _notesCtrl = TextEditingController(text: edit?.notes ?? '');
    _selectedCategory = edit?.category ?? 'promotion';
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
          data: (dark ? ThemeData.dark() : ThemeData.light()).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              surface: dark ? AppColors.darkCard : Colors.white,
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final parsedAmount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (parsedAmount == null || parsedAmount <= 0) {
      Get.snackbar(
        'Invalid Amount',
        'Please enter a valid expense amount greater than 0',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (widget.recordToEdit != null) {
        final updated = widget.recordToEdit!.copyWith(
          title: _titleCtrl.text.trim(),
          amount: parsedAmount,
          category: _selectedCategory,
          date: _selectedDate,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
        await widget.controller.updateCostRecord(updated);
      } else {
        await widget.controller.addCostRecord(
          title: _titleCtrl.text.trim(),
          amount: parsedAmount,
          category: _selectedCategory,
          date: _selectedDate,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        Get.snackbar(
          widget.recordToEdit != null ? 'Cost Updated' : 'Cost Deducted',
          'ETB ${NumberFormat('#,##0.00').format(parsedAmount)} has been deducted from revenue analytics.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final isEditing = widget.recordToEdit != null;

    return Dialog(
      backgroundColor: dark ? AppColors.darkCard : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Dialog Header ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Iconsax.wallet_minus_copy,
                              size: 20,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing ? 'Edit Cost Entry' : 'Enter Promotion / Cost',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: dark ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                                const Text(
                                  'Deducts automatically from gross revenue',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                const Divider(height: 1),
                const SizedBox(height: AppSizes.md),

                // ── Amount Input ───────────────────────────────────────────
                const Text(
                  'COST AMOUNT *',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  autofocus: !isEditing,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      width: 50,
                      child: Text(
                        'ETB',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: dark ? Colors.white70 : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    hintText: '0.00',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter cost amount';
                    }
                    final num = double.tryParse(val.replaceAll(',', ''));
                    if (num == null || num <= 0) {
                      return 'Enter a positive amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Quick Amount Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickAmounts.map((amt) {
                    return InkWell(
                      onTap: () {
                        final current = double.tryParse(_amountCtrl.text) ?? 0;
                        _amountCtrl.text = (current + amt).toStringAsFixed(0);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: dark
                              ? AppColors.darkSurface
                              : AppColors.grey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: dark
                                ? AppColors.darkBorder
                                : AppColors.borderPrimary,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          '+$amt',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: dark ? Colors.white70 : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSizes.md),

                // ── Category Selector ──────────────────────────────────────
                const Text(
                  'CATEGORY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    final color = RevenueCostRecord.getCategoryColor(cat);
                    final icon = RevenueCostRecord.getCategoryIcon(cat);
                    final label = RevenueCostRecord.getCategoryLabel(cat);

                    return InkWell(
                      onTap: () => setState(() => _selectedCategory = cat),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.18)
                              : (dark ? AppColors.darkSurface : AppColors.lightGrey),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? color
                                : (dark
                                    ? AppColors.darkBorder
                                    : AppColors.borderPrimary),
                            width: isSelected ? 1.4 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 13,
                              color: isSelected ? color : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? (dark ? Colors.white : color)
                                    : (dark
                                        ? Colors.white70
                                        : AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSizes.md),

                // ── Purpose / Description Input ─────────────────────────────
                const Text(
                  'PURPOSE / DESCRIPTION *',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Telegram Channel Promo, TikTok Ad',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please provide a title or purpose';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),

                // Suggestion Presets
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _titlePresets.map((preset) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () => setState(() => _titleCtrl.text = preset),
                          borderRadius: BorderRadius.circular(5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: dark
                                  ? AppColors.darkSurface
                                  : AppColors.grey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              preset,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSizes.md),

                // ── Expense Date & Notes Row ───────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DATE INCURRED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(
                              AppSizes.borderRadiusSm,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: dark
                                    ? AppColors.darkSurface
                                    : AppColors.lightGrey,
                                borderRadius: BorderRadius.circular(
                                  AppSizes.borderRadiusSm,
                                ),
                                border: Border.all(
                                  color: dark
                                      ? AppColors.darkBorder
                                      : AppColors.borderPrimary,
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Iconsax.calendar_1_copy,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat('d MMM yyyy').format(_selectedDate),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: dark
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),

                // ── Optional Notes ─────────────────────────────────────────
                const Text(
                  'NOTES / RECEIPT REF (OPTIONAL)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Additional details, receipt link, or payment ref',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.lg),

                // ── Action Buttons ─────────────────────────────────────────
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (isEditing)
                      TextButton.icon(
                        icon: const Icon(
                          Iconsax.trash_copy,
                          size: 15,
                          color: AppColors.error,
                        ),
                        label: const Text(
                          'Delete',
                          style: TextStyle(color: AppColors.error),
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                final nav = Navigator.of(context);
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Cost Entry?'),
                                    content: const Text(
                                      'This cost will be deleted and the amount will be restored to your revenue.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.error,
                                        ),
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await widget.controller.deleteCostRecord(
                                    widget.recordToEdit!.id,
                                  );
                                  nav.pop();
                                }
                              },
                      ),
                    OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton.icon(
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Iconsax.tick_circle_copy, size: 16),
                      label: Text(
                        isEditing ? 'Save Changes' : 'Deduct from Revenue',
                      ),
                      onPressed: _isSubmitting ? null : _submit,
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
