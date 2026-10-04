import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:m_admin/utils/constants/colors.dart';

class AdminAuditLogModel {
  final int id;
  final String adminUid;
  final String action;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final String? note;
  final DateTime createdAt;

  const AdminAuditLogModel({
    required this.id,
    required this.adminUid,
    required this.action,
    required this.entityType,
    this.entityId,
    this.before,
    this.after,
    this.note,
    required this.createdAt,
  });

  factory AdminAuditLogModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parseJsonField(dynamic field) {
      if (field == null) return null;
      if (field is Map) return Map<String, dynamic>.from(field);
      if (field is String && field.isNotEmpty) {
        try {
          return Map<String, dynamic>.from(jsonDecode(field) as Map);
        } catch (_) {}
      }
      return null;
    }

    return AdminAuditLogModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      adminUid: json['admin_uid']?.toString() ?? 'system',
      action: json['action']?.toString() ?? 'action',
      entityType: json['entity_type']?.toString() ?? 'entity',
      entityId: json['entity_id']?.toString(),
      before: parseJsonField(json['before']),
      after: parseJsonField(json['after']),
      note: json['note']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Color get actionColor {
    final act = action.toLowerCase();
    if (act.contains('approve') || act.contains('create') || act.contains('grant')) {
      return AppColors.success;
    }
    if (act.contains('reject') || act.contains('delete') || act.contains('ban') || act.contains('remove')) {
      return AppColors.error;
    }
    if (act.contains('update') || act.contains('edit') || act.contains('reset')) {
      return AppColors.warning;
    }
    if (act.contains('broadcast') || act.contains('notify')) {
      return AppColors.info;
    }
    return AppColors.primary;
  }

  String get formattedAction {
    return action.replaceAll('_', ' ').toUpperCase();
  }
}
