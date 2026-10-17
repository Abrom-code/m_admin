import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/helpers/ethiopian_time_helper.dart';

/// Represents an entered promotion or operational expense that is deducted from gross revenue.
class RevenueCostRecord {
  const RevenueCostRecord({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String title;
  final double amount;

  /// Category key, e.g. 'promotion', 'social_ads', 'influencer', 'server', 'sms', 'other'.
  final String category;

  /// The date when the expense occurred.
  final DateTime date;

  /// Optional extra details or transaction note.
  final String? notes;

  /// When the record was logged.
  final DateTime createdAt;

  RevenueCostRecord copyWith({
    String? id,
    String? title,
    double? amount,
    String? category,
    DateTime? date,
    String? notes,
    DateTime? createdAt,
  }) {
    return RevenueCostRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory RevenueCostRecord.fromJson(Map<String, dynamic> json) {
    return RevenueCostRecord(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Cost',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category']?.toString() ?? 'promotion',
      date: json['date'] != null
          ? EthiopianTimeHelper.parseToEastAfricaTime(json['date']) ?? DateTime.now()
          : DateTime.now(),
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null
          ? EthiopianTimeHelper.parseToEastAfricaTime(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  // ── Category Helpers ──────────────────────────────────────────────────────

  static String getCategoryLabel(String cat) {
    switch (cat.toLowerCase()) {
      case 'promotion':
        return 'Promotion';
      case 'social_ads':
        return 'Social Ads';
      case 'influencer':
        return 'Influencer';
      case 'server':
        return 'Server & Hosting';
      case 'sms':
        return 'SMS Gateway';
      case 'other':
      default:
        return 'Other Cost';
    }
  }

  static IconData getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'promotion':
        return Iconsax.ranking_copy;
      case 'social_ads':
        return Iconsax.global_copy;
      case 'influencer':
        return Iconsax.user_tag_copy;
      case 'server':
        return Iconsax.cloud_connection_copy;
      case 'sms':
        return Iconsax.message_copy;
      case 'other':
      default:
        return Iconsax.receipt_2_copy;
    }
  }

  static Color getCategoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'promotion':
        return const Color(0xFF8B5CF6); // Purple
      case 'social_ads':
        return const Color(0xFF3B82F6); // Blue
      case 'influencer':
        return const Color(0xFFEC4899); // Pink
      case 'server':
        return const Color(0xFF10B981); // Emerald
      case 'sms':
        return const Color(0xFFF59E0B); // Amber
      case 'other':
      default:
        return AppColors.darkGrey;
    }
  }
}
