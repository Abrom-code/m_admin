import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/features/challenges/controllers/admin_leaderboard_controller.dart';
import 'package:m_admin/features/challenges/models/challenge_leaderboard_entry.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

class GrantRewardDialog extends StatefulWidget {
  const GrantRewardDialog({
    super.key,
    required this.entry,
    required this.controller,
  });

  final ChallengeLeaderboardEntry entry;
  final AdminLeaderboardController controller;

  static Future<bool?> show(
    BuildContext context, {
    required ChallengeLeaderboardEntry entry,
    required AdminLeaderboardController controller,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => GrantRewardDialog(
        entry: entry,
        controller: controller,
      ),
    );
  }

  @override
  State<GrantRewardDialog> createState() => _GrantRewardDialogState();
}

class _GrantRewardDialogState extends State<GrantRewardDialog> {
  String _rewardType = 'premium_days';
  final _rewardValueCtrl = TextEditingController(text: '30');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _rewardValueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.sm),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.award_copy,
              color: AppColors.primary,
              size: AppSizes.iconMd,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          const Expanded(
            child: Text(
              'Grant Challenge Reward',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Student Summary Card ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(
                  color: dark ? AppColors.darkContainer : AppColors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        widget.entry.firstName.isNotEmpty
                            ? widget.entry.firstName[0].toUpperCase()
                            : 'S',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.entry.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Rank #${widget.entry.rank} • Score: ${widget.entry.score} • ${widget.entry.stream.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 11,
                              color: dark ? Colors.white70 : AppColors.darkGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.spaceBtwItems),

              // ── Reward Type Dropdown ──────────────────────────────
              const Text(
                'Reward Type',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: AppSizes.xs),
              DropdownButtonFormField<String>(
                initialValue: _rewardType,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm)),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'premium_days',
                    child: Text('Premium Days (Auto-extends subscription)'),
                  ),
                  DropdownMenuItem(
                    value: 'badge',
                    child: Text('Special Badge / Title'),
                  ),
                  DropdownMenuItem(
                    value: 'coupon',
                    child: Text('Discount Coupon Code'),
                  ),
                  DropdownMenuItem(
                    value: 'custom',
                    child: Text('Custom Prize / Recognition'),
                  ),
                ],
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _rewardType = val;
                    if (val == 'premium_days') {
                      _rewardValueCtrl.text = '30';
                    } else if (val == 'badge') {
                      _rewardValueCtrl.text = 'Gold Scholar';
                    } else if (val == 'coupon') {
                      _rewardValueCtrl.text = 'MATRIC50';
                    }
                  });
                },
              ),
              const SizedBox(height: AppSizes.spaceBtwItems),

              // ── Reward Value ─────────────────────────────────────
              Text(
                _rewardType == 'premium_days'
                    ? 'Days to Grant (e.g. 30, 60, 90)'
                    : 'Reward Detail / Value',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: AppSizes.xs),
              TextFormField(
                controller: _rewardValueCtrl,
                keyboardType: _rewardType == 'premium_days'
                    ? TextInputType.number
                    : TextInputType.text,
                decoration: InputDecoration(
                  hintText: _rewardType == 'premium_days'
                      ? '30'
                      : 'Enter reward code or title',
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a value';
                  }
                  if (_rewardType == 'premium_days' && int.tryParse(val.trim()) == null) {
                    return 'Please enter a valid number of days';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        Obx(
          () => FilledButton.icon(
            onPressed: widget.controller.isGranting.value
                ? null
                : () async {
                    if (!_formKey.currentState!.validate()) return;
                    final ok = await widget.controller.grantReward(
                      userId: widget.entry.userId,
                      rank: widget.entry.rank,
                      rewardType: _rewardType,
                      rewardValue: _rewardValueCtrl.text.trim(),
                    );
                    if (ok && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
            icon: widget.controller.isGranting.value
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Iconsax.gift_copy, size: AppSizes.iconSm),
            label: const Text('Grant Reward'),
          ),
        ),
      ],
    );
  }
}
