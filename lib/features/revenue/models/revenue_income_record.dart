import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/helpers/ethiopian_time_helper.dart';

/// Represents a manual income/revenue entry (e.g., direct bank transfer, cash, bulk license).
class RevenueIncomeRecord {
  const RevenueIncomeRecord({
    required this.id,
    required this.title,
    required this.amount,
    required this.paymentMethod,
    required this.date,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String title;
  final double amount;

  /// Payment method key: 'telebirr', 'cbe', 'abyssinia', 'mpesa', 'cash', 'bank_transfer', 'other'.
  final String paymentMethod;

  /// The date when the income occurred.
  final DateTime date;

  /// Optional extra details or transaction note.
  final String? notes;

  /// When the record was logged.
  final DateTime createdAt;

  RevenueIncomeRecord copyWith({
    String? id,
    String? title,
    double? amount,
    String? paymentMethod,
    DateTime? date,
    String? notes,
    DateTime? createdAt,
  }) {
    return RevenueIncomeRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'payment_method': paymentMethod,
        'date': date.toIso8601String(),
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory RevenueIncomeRecord.fromJson(Map<String, dynamic> json) {
    return RevenueIncomeRecord(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Income',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method']?.toString() ?? 'telebirr',
      date: json['date'] != null
          ? EthiopianTimeHelper.parseToEastAfricaTime(json['date']) ?? DateTime.now()
          : DateTime.now(),
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null
          ? EthiopianTimeHelper.parseToEastAfricaTime(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  // ── Payment Method Helpers ────────────────────────────────────────────────

  static String getMethodLabel(String method) {
    final m = method.toLowerCase().replaceAll('payment_', '').replaceAll('_birr', '');
    switch (m) {
      case 'telebirr':
        return 'Telebirr';
      case 'cbe':
        return 'Commercial Bank (CBE)';
      case 'abyssinia':
        return 'Bank of Abyssinia';
      case 'mpesa':
        return 'M-Pesa';
      case 'cash':
        return 'Direct Cash';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'other':
      default:
        return 'Other Income';
    }
  }

  static IconData getMethodIcon(String method) {
    final m = method.toLowerCase();
    if (m.contains('telebirr')) return Iconsax.mobile_copy;
    if (m.contains('cbe')) return Iconsax.bank_copy;
    if (m.contains('abyssinia')) return Iconsax.card_copy;
    if (m.contains('mpesa')) return Iconsax.money_send_copy;
    if (m.contains('cash')) return Iconsax.wallet_add_copy;
    if (m.contains('transfer')) return Iconsax.arrow_swap_horizontal_copy;
    return Iconsax.dollar_circle_copy;
  }

  static Color getMethodColor(String method) {
    final m = method.toLowerCase();
    if (m.contains('telebirr')) return const Color(0xFF005EB8);
    if (m.contains('cbe')) return const Color(0xFF8B1874);
    if (m.contains('abyssinia')) return const Color(0xFFD4A017);
    if (m.contains('mpesa')) return const Color(0xFF00A859);
    if (m.contains('cash')) return const Color(0xFF10B981);
    if (m.contains('transfer')) return const Color(0xFF3B82F6);
    return AppColors.primary;
  }
}
