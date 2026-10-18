import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:m_admin/features/revenue/models/revenue_cost_record.dart';
import 'package:m_admin/features/revenue/models/revenue_income_record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for persisting entered promotion/operational costs and manual income/revenue.
/// Uses a dual-layer strategy: local fast cache via [GetStorage] + cloud sync via Supabase `app_config`.
class RevenueCostsRepository {
  RevenueCostsRepository({SupabaseClient? client, GetStorage? storage})
      : _client = client,
        _storage = storage ?? GetStorage();

  static const String storageKey = 'revenue_costs_records';
  static const String configKey = 'revenue_costs_records';

  static const String incomeStorageKey = 'revenue_income_records';
  static const String incomeConfigKey = 'revenue_income_records';

  final SupabaseClient? _client;
  final GetStorage _storage;

  SupabaseClient? get _sb {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Loads costs from local storage first (instant), then attempts to sync from Supabase `app_config`.
  Future<List<RevenueCostRecord>> loadCosts() async {
    // 1. Read local cache
    final localList = _loadFromLocalStorage();

    // 2. Fetch latest from Supabase app_config in background or async
    final client = _sb;
    if (client != null) {
      try {
        final rows = await client
            .from('app_config')
            .select('value')
            .eq('key', configKey)
            .maybeSingle();

        if (rows != null && rows['value'] != null) {
          final rawVal = rows['value'].toString();
          if (rawVal.trim().isNotEmpty) {
            final decoded = jsonDecode(rawVal);
            if (decoded is List) {
              final cloudList = decoded
                  .map((e) => RevenueCostRecord.fromJson(
                      Map<String, dynamic>.from(e as Map)))
                  .toList();

              // Merge cloud and local by ID, preferring cloud if newer
              final mergedMap = <String, RevenueCostRecord>{};
              for (final r in localList) {
                mergedMap[r.id] = r;
              }
              for (final r in cloudList) {
                mergedMap[r.id] = r;
              }

              final merged = mergedMap.values.toList()
                ..sort((a, b) => b.date.compareTo(a.date));

              // Persist back to local storage
              _saveToLocalStorage(merged);
              return merged;
            }
          }
        } else if (localList.isNotEmpty) {
          // First time cloud sync: push local data to app_config
          await _saveToCloud(localList);
        }
      } catch (e) {
        debugPrint('[RevenueCostsRepository] Cloud fetch error (using local): $e');
      }
    }

    return localList;
  }

  /// Saves the complete list of cost records to both local storage and Supabase `app_config`.
  Future<void> saveCosts(List<RevenueCostRecord> list) async {
    // 1. Instant local persistence
    _saveToLocalStorage(list);

    // 2. Cloud sync via Supabase app_config
    try {
      await _saveToCloud(list);
    } catch (e) {
      debugPrint('[RevenueCostsRepository] Cloud save error: $e');
    }
  }

  List<RevenueCostRecord> _loadFromLocalStorage() {
    try {
      final raw = _storage.read<List<dynamic>>(storageKey);
      if (raw == null) return [];
      return raw
          .map((e) =>
              RevenueCostRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      debugPrint('[RevenueCostsRepository] Local storage read error: $e');
      return [];
    }
  }

  void _saveToLocalStorage(List<RevenueCostRecord> list) {
    try {
      final jsonList = list.map((r) => r.toJson()).toList();
      _storage.write(storageKey, jsonList);
    } catch (e) {
      debugPrint('[RevenueCostsRepository] Local storage write error: $e');
    }
  }

  Future<void> _saveToCloud(List<RevenueCostRecord> list) async {
    final client = _sb;
    if (client == null) return;
    final encoded = jsonEncode(list.map((r) => r.toJson()).toList());
    await client.from('app_config').upsert(
      {
        'key': configKey,
        'value': encoded,
      },
      onConflict: 'key',
    );
  }

  // ── Manual Revenue / Income CRUD ──────────────────────────────────────────

  /// Loads manual income records from local storage first, then syncs with Supabase `app_config`.
  Future<List<RevenueIncomeRecord>> loadIncome() async {
    final localList = _loadIncomeFromLocalStorage();

    final client = _sb;
    if (client != null) {
      try {
        final rows = await client
            .from('app_config')
            .select('value')
            .eq('key', incomeConfigKey)
            .maybeSingle();

        if (rows != null && rows['value'] != null) {
          final rawVal = rows['value'].toString();
          if (rawVal.trim().isNotEmpty) {
            final decoded = jsonDecode(rawVal);
            if (decoded is List) {
              final cloudList = decoded
                  .map((e) => RevenueIncomeRecord.fromJson(
                      Map<String, dynamic>.from(e as Map)))
                  .toList();

              final mergedMap = <String, RevenueIncomeRecord>{};
              for (final r in localList) {
                mergedMap[r.id] = r;
              }
              for (final r in cloudList) {
                mergedMap[r.id] = r;
              }

              final merged = mergedMap.values.toList()
                ..sort((a, b) => b.date.compareTo(a.date));

              _saveIncomeToLocalStorage(merged);
              return merged;
            }
          }
        } else if (localList.isNotEmpty) {
          await _saveIncomeToCloud(localList);
        }
      } catch (e) {
        debugPrint('[RevenueCostsRepository] Income cloud fetch error (using local): $e');
      }
    }

    return localList;
  }

  /// Saves the complete list of income records to both local storage and Supabase `app_config`.
  Future<void> saveIncome(List<RevenueIncomeRecord> list) async {
    _saveIncomeToLocalStorage(list);

    try {
      await _saveIncomeToCloud(list);
    } catch (e) {
      debugPrint('[RevenueCostsRepository] Income cloud save error: $e');
    }
  }

  List<RevenueIncomeRecord> _loadIncomeFromLocalStorage() {
    try {
      final raw = _storage.read<List<dynamic>>(incomeStorageKey);
      if (raw == null) return [];
      return raw
          .map((e) =>
              RevenueIncomeRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      debugPrint('[RevenueCostsRepository] Local storage read income error: $e');
      return [];
    }
  }

  void _saveIncomeToLocalStorage(List<RevenueIncomeRecord> list) {
    try {
      final jsonList = list.map((r) => r.toJson()).toList();
      _storage.write(incomeStorageKey, jsonList);
    } catch (e) {
      debugPrint('[RevenueCostsRepository] Local storage write income error: $e');
    }
  }

  Future<void> _saveIncomeToCloud(List<RevenueIncomeRecord> list) async {
    final client = _sb;
    if (client == null) return;
    final encoded = jsonEncode(list.map((r) => r.toJson()).toList());
    await client.from('app_config').upsert(
      {
        'key': incomeConfigKey,
        'value': encoded,
      },
      onConflict: 'key',
    );
  }
}

