import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:m_admin/data/services/receipt_extractor_service.dart';
import 'package:m_admin/data/services/scanned_receipt_storage.dart';
import 'package:m_admin/features/payments/models/verify_et_model.dart';

/// Service implementing official Verify.ET Ethiopian payment verification (https://verify.et/docs/api).
/// Verifies payments directly from upstream Ethiopian banks and wallets:
/// Telebirr, CBE, Bank of Abyssinia, Awash, Dashen, CBE Birr, M-Pesa, Siinqee, Kaafiebirr, Coopay-eBirr.
class VerifyEtService extends GetxService {
  static VerifyEtService get instance => Get.isRegistered<VerifyEtService>()
      ? Get.find<VerifyEtService>()
      : Get.put(VerifyEtService(), permanent: true);

  static const String defaultBaseUrl = 'https://verify.et';
  static const String _kApiKeyStorageKey = 'verify_et_api_key';
  static const String _kLegacyApiKeyStorageKey = 'links_et_api_key';

  final apiKey = ''.obs;
  final scannedStorage = ScannedReceiptStorage.instance;

  @override
  void onInit() {
    super.onInit();
    String? storedKey;
    try {
      final box = GetStorage();
      storedKey = box.read<String>(_kApiKeyStorageKey)?.trim();
      if (storedKey == null || storedKey.isEmpty) {
        storedKey = box.read<String>(_kLegacyApiKeyStorageKey)?.trim();
      }
    } catch (_) {}

    String? envKey;
    try {
      envKey = dotenv.env['VERIFY_ET_API_KEY']?.trim();
      if (envKey == null || envKey.isEmpty) {
        envKey = dotenv.env['LINKS_ET_API_KEY']?.trim();
      }
    } catch (_) {}

    // If stored key was an old legacy links.et key (vk_live_...) while env has a new VERIFY_BANK_ET_... key,
    // prioritize the fresh env key.
    if (storedKey != null &&
        storedKey.startsWith('vk_') &&
        envKey != null &&
        envKey.startsWith('VERIFY_BANK_ET_')) {
      apiKey.value = envKey;
    } else {
      apiKey.value = (storedKey != null && storedKey.isNotEmpty)
          ? storedKey
          : (envKey ?? '');
    }
  }

  bool get hasApiKey => apiKey.value.trim().isNotEmpty;

  String get keyPrefix {
    final k = apiKey.value.trim();
    if (k.length <= 15) return k;
    return k.substring(0, 15);
  }

  void saveApiKey(String newKey) {
    final trimmed = newKey.trim();
    apiKey.value = trimmed;
    try {
      final box = GetStorage();
      box.write(_kApiKeyStorageKey, trimmed);
      box.write(_kLegacyApiKeyStorageKey, trimmed);
    } catch (_) {}
  }

  Map<String, String> _buildHeaders({String? idempotencyKey}) {
    final key = apiKey.value.trim();
    return {
      'x-api-key': key,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        'Idempotency-Key': idempotencyKey,
    };
  }

  /// Resolves the default MatricMate settlement account for a given bank.
  /// Telebirr: 0960586811, CBE: 1000435011237, Abyssinia: 165093089.
  static String resolveDefaultSettlementAccount(String bank) {
    final b = bank.toLowerCase().trim();
    if (b.contains('telebirr')) return '0960586811';
    if (b.contains('cbe') && !b.contains('cbebirr')) return '1000435011237';
    if (b.contains('boa') || b.contains('abyssinia')) return '165093089';
    return '';
  }

  /// Resolves the default account suffix for bank verification.
  /// Bank of Abyssinia strictly requires 5 digits (93089).
  /// CBE strictly requires exactly 8 digits: for MatricMate's receiving account 1000435011237,
  /// the 8-digit suffix is 35011237.
  static String resolveDefaultAccountSuffix(String bank) {
    final b = bank.toLowerCase().trim();
    if (b.contains('boa') || b.contains('abyssinia')) return '93089';
    if (b.contains('cbe') && !b.contains('cbebirr')) return '35011237';
    return '';
  }

  /// Sanitizes an account suffix according to bank-specific requirements:
  /// - CBE: Strictly 8 digits. If a user provides a full 13-digit account (e.g. 1000435011237)
  ///   or 9 digits (435011237), this extracts the last 8 digits (35011237).
  /// - BOA: Strictly 5 digits. If a user provides a full account (e.g. 165093089),
  ///   this extracts the last 5 digits (93089).
  static String sanitizeAccountSuffix(String input, String bank) {
    final digits = input.replaceAll(RegExp(r'\D'), '').trim();
    if (digits.isEmpty) return '';
    final b = bank.toLowerCase().trim();
    if (b.contains('cbe') && !b.contains('cbebirr')) {
      if (digits.length >= 8) {
        return digits.substring(digits.length - 8);
      }
      return digits;
    }
    if (b.contains('boa') || b.contains('abyssinia')) {
      if (digits.length >= 5) {
        return digits.substring(digits.length - 5);
      }
      return digits;
    }
    return digits;
  }

  /// Sanitizes Telebirr input by extracting a clean 10-char reference code or standard URL.
  static String sanitizeTelebirrReference(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return '';

    // If it is a full transactioninfo.ethiotelecom.et URL
    final urlRegex = RegExp(
      r'(?:https?:\/\/)?transactioninfo\.ethiotelecom\.et\/receipt\/([A-Za-z0-9]+)',
      caseSensitive: false,
    );
    final urlMatch = urlRegex.firstMatch(clean);
    if (urlMatch != null) {
      return urlMatch.group(1)!.toUpperCase();
    }

    // If it has label prefix like "Transaction No: ABCD1234EF" or "Lakkoofsa Kaffaltii ABCD1234EF"
    final labeledRegex = RegExp(
      r'(?:Transaction\s*(?:No|Number|ID|Code)|Payment\s*Code|Lakkoofsa\s*Kaffaltii|Lakkoofsa\s*daddabarsaa|የግብይት\s*ቁጥር|የሂሳብ\s*ቁጥር|Ref(?:erence)?)[\s:]*([A-Za-z0-9]{10})\b',
      caseSensitive: false,
    );
    final labeledMatch = labeledRegex.firstMatch(clean);
    if (labeledMatch != null) {
      return labeledMatch.group(1)!.toUpperCase();
    }

    // If it starts with http, return as clean URL
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }

    // If it's a 10-char alphanumeric token
    final tokenRegex = RegExp(r'\b([A-Za-z0-9]{10})\b');
    final match = tokenRegex.firstMatch(clean);
    if (match != null) {
      return match.group(1)!.toUpperCase();
    }

    // Fallback: strip punctuation and whitespace
    return clean.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
  }

  /// Intelligently resolves raw user input (URLs, references, tokens, or confirmation SMS)
  /// into the appropriate Verify.ET payload, handling Ethiopian bank quirks:
  ///
  /// - **Telebirr**: Extracts clean 10-char reference code or validates URL.
  /// - **Bank of Abyssinia (BOA)**: Auto-expands reference tokens (`FT...`) into
  ///   `https://cs.bankofabyssinia.com/slip/?trx=<TOKEN>`, and normalizes `?id=` to `?trx=`.
  /// - **Commercial Bank of Ethiopia (CBE)**:
  ///   - Extracts receipt links embedded inside raw CBE SMS text.
  ///   - Expands dashed SMS IDs (`FT...-12345678`) to `https://mbreciept.cbe.com.et/<id>`.
  ///   - Expands mobile tokens (`fHCxz...`) to `https://mbreciept.cbe.com.et/<token>`.
  ///   - Expands bare `FT...` references to candidate `https://apps.cbe.com.et:100/?id=<ref>`.
  ///   - Normalizes missing `https://` on `mbreciept.cbe.com.et` and `apps.cbe.com.et`.
  /// - **Awash / Zemen / Others**: Expands tokens and ensures `https://` scheme.
  static ResolvedReceiptInput resolveReceiptInput({
    required String input,
    required String bank,
  }) {
    final raw = input.trim();
    if (raw.isEmpty) {
      return ResolvedReceiptInput(
        resolvedBank: bank.toLowerCase().trim(),
        note: 'Input is empty',
      );
    }

    final b = bank.toLowerCase().trim();

    // ── 1. Check if raw input contains an embedded HTTP/HTTPS URL anywhere (e.g. from SMS) ──
    final embeddedUrlRegex = RegExp(
      r'(https?:\/\/[^\s<>"{}|\^`\\]+)',
      caseSensitive: false,
    );
    final urlMatch = embeddedUrlRegex.firstMatch(raw);

    if (urlMatch != null) {
      var foundUrl = urlMatch.group(1)!.trim();
      // Clean trailing punctuation attached from sentence ending (. or , or ))
      foundUrl = foundUrl.replaceAll(RegExp(r'[\.,;:\)\]\>]+$'), '');

      // Bank of Abyssinia URL normalization: Verify.et accepts ?trx=, not ?id=
      if (foundUrl.contains('cs.bankofabyssinia.com')) {
        if (foundUrl.contains('/slip/?id=')) {
          foundUrl = foundUrl.replaceAll('/slip/?id=', '/slip/?trx=');
        } else if (foundUrl.contains('/slip/&id=')) {
          foundUrl = foundUrl.replaceAll('/slip/&id=', '/slip/?trx=');
        }
        return ResolvedReceiptInput(
          url: foundUrl,
          resolvedBank: 'boa',
          displayUrl: foundUrl,
          isAutoConstructed: foundUrl != raw,
          note: 'Extracted Bank of Abyssinia slip URL',
        );
      }

      // CBE URL normalization
      if (foundUrl.contains('cbe.com.et')) {
        return ResolvedReceiptInput(
          url: foundUrl,
          resolvedBank: 'cbe',
          displayUrl: foundUrl,
          isAutoConstructed: foundUrl != raw,
          note: 'Extracted CBE receipt URL from SMS/text',
        );
      }

      // Awash URL
      if (foundUrl.contains('awashbank.com')) {
        return ResolvedReceiptInput(
          url: foundUrl,
          resolvedBank: 'awash',
          displayUrl: foundUrl,
          isAutoConstructed: foundUrl != raw,
          note: 'Extracted AwashPay receipt URL',
        );
      }

      // Zemen URL
      if (foundUrl.contains('zemenbank.com')) {
        return ResolvedReceiptInput(
          url: foundUrl,
          resolvedBank: 'zemen',
          displayUrl: foundUrl,
          isAutoConstructed: foundUrl != raw,
          note: 'Extracted Zemen Bank receipt URL',
        );
      }

      // Telebirr URL
      if (foundUrl.contains('transactioninfo.ethiotelecom.et')) {
        final ref = sanitizeTelebirrReference(foundUrl);
        return ResolvedReceiptInput(
          reference: ref,
          resolvedBank: 'telebirr',
          displayUrl: 'transactioninfo.ethiotelecom.et/receipt/$ref',
          isAutoConstructed: true,
          note: 'Extracted Telebirr receipt reference',
        );
      }

      // Generic URL fallback
      return ResolvedReceiptInput(
        url: foundUrl,
        resolvedBank: b.isEmpty ? 'universal' : b,
        displayUrl: foundUrl,
      );
    }

    // ── 2. Bank of Abyssinia (BOA) ───────────────────────────────────────────
    if (b == 'boa' || b == 'abyssinia') {
      // If starts with cs.bankofabyssinia.com without https://
      if (raw.toLowerCase().contains('cs.bankofabyssinia.com')) {
        var cleanUrl = raw.startsWith('http') ? raw : 'https://$raw';
        cleanUrl = cleanUrl.replaceAll('/slip/?id=', '/slip/?trx=');
        final m = RegExp(r'[?&]trx=([A-Za-z0-9]+)').firstMatch(cleanUrl);
        final token = m?.group(1);
        return ResolvedReceiptInput(
          url: cleanUrl,
          reference: token,
          resolvedBank: 'boa',
          displayUrl: cleanUrl,
          accountSuffix: resolveDefaultAccountSuffix('boa'),
        );
      }

      // If user typed `trx=...` or `id=...`
      final trxParamMatch = RegExp(r'(?:trx|id)=([A-Za-z0-9]+)', caseSensitive: false).firstMatch(raw);
      if (trxParamMatch != null) {
        final token = trxParamMatch.group(1)!;
        final boaUrl = 'https://cs.bankofabyssinia.com/slip/?trx=$token';
        return ResolvedReceiptInput(
          url: boaUrl,
          reference: token,
          resolvedBank: 'boa',
          displayUrl: boaUrl,
          isAutoConstructed: true,
          note: 'Auto-formatted to Bank of Abyssinia slip URL',
          accountSuffix: resolveDefaultAccountSuffix('boa'),
        );
      }

      // Check for structured FT transaction ID and sender/receiver accounts
      // e.g. "sender 178635107 receiver(me)165093089 transaction id FT263180M1GN"
      // or "debited from 178635107 for 165093089 ... FT263180M1GN"
      // or "FT263180M1GN 178635107" or "FT263180M1GN-35107"
      final ftMatch = RegExp(
        r'\b((?:FT|ET|TT|FI|FL|F1|F\|)[\s\-_.:/]*[0-9IILOQSBZ|!]{5}[\s\-_.:/]*[0-9A-Za-z|!]{4,8})\b',
        caseSensitive: false,
      ).firstMatch(raw);

      final senderMatch = RegExp(
        r'(?:sender\s*(?:account)?|from\s*account|source\s*account|debited\s*from)[\s:(me)]*([0-9]{5,16})',
        caseSensitive: false,
      ).firstMatch(raw);

      if (ftMatch != null) {
        final cleanFt = ReceiptTextParser.normalizeCbeFtReference(ftMatch.group(1)!);
        String? suffix;
        if (senderMatch != null) {
          suffix = sanitizeAccountSuffix(senderMatch.group(1)!, 'boa');
        } else {
          // Look for an extra 5-16 digit account number in raw that is not the FT code digits
          final digitMatches = RegExp(r'\b([0-9]{5,16})\b').allMatches(raw);
          for (final dm in digitMatches) {
            final val = dm.group(1)!;
            if (!cleanFt.contains(val)) {
              suffix = sanitizeAccountSuffix(val, 'boa');
              break;
            }
          }
        }

        final boaUrl = 'https://cs.bankofabyssinia.com/slip/?trx=$cleanFt';
        return ResolvedReceiptInput(
          url: boaUrl,
          reference: cleanFt,
          resolvedBank: 'boa',
          displayUrl: boaUrl,
          isAutoConstructed: true,
          note: suffix != null
              ? 'Bank of Abyssinia FT ($cleanFt) with sender suffix $suffix'
              : 'Bank of Abyssinia FT reference ($cleanFt)',
          accountSuffix: suffix ?? resolveDefaultAccountSuffix('boa'),
        );
      }

      // Extract transaction token / reference (strip prefixes like "Ref:", "Tx:", "Slip:")
      final cleanedToken = raw
          .replaceAll(RegExp(r'^(?:Ref(?:erence)?|Transaction\s*(?:No|ID|Code)|Slip|የግብይት\s*ቁጥር)[\s:]*', caseSensitive: false), '')
          .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
          .trim();

      if (cleanedToken.isNotEmpty) {
        final boaUrl = 'https://cs.bankofabyssinia.com/slip/?trx=$cleanedToken';
        return ResolvedReceiptInput(
          url: boaUrl,
          reference: cleanedToken,
          resolvedBank: 'boa',
          displayUrl: boaUrl,
          isAutoConstructed: true,
          note: 'Auto-formatted reference to Bank of Abyssinia slip URL ($cleanedToken)',
          accountSuffix: resolveDefaultAccountSuffix('boa'),
        );
      }
    }

    // ── 3. Commercial Bank of Ethiopia (CBE) ─────────────────────────────────
    if (b == 'cbe' || b == 'cbebirr') {
      // If starts with domain without scheme (e.g. mbreciept.cbe.com.et/...)
      if (raw.toLowerCase().startsWith('mbreciept.cbe.com.et') ||
          raw.toLowerCase().startsWith('mreciept.cbe.com.et') ||
          raw.toLowerCase().startsWith('apps.cbe.com.et') ||
          raw.toLowerCase().startsWith('mb.cbe.com.et')) {
        final cleanUrl = 'https://$raw';
        final token = cleanUrl.split('/').last;
        return ResolvedReceiptInput(
          url: cleanUrl,
          reference: token,
          resolvedBank: 'cbe',
          displayUrl: cleanUrl,
          accountSuffix: token.contains('-') ? token.split('-').last : null,
        );
      }

      // If dashed SMS token: e.g. FT26291KVDWY-10004350 or FT...-...
      final dashedMatch = RegExp(r'\b(FT[0-9A-Za-z]+)-(\d+)\b', caseSensitive: false).firstMatch(raw);
      if (dashedMatch != null) {
        final dashedId = dashedMatch.group(0)!;
        final ftRef = dashedMatch.group(1)!.toUpperCase();
        final rawSuffix = dashedMatch.group(2)!;
        final suffix = sanitizeAccountSuffix(rawSuffix, 'cbe');
        final cbeUrl = 'https://mbreciept.cbe.com.et/$dashedId';
        return ResolvedReceiptInput(
          url: cbeUrl,
          reference: ftRef,
          resolvedBank: 'cbe',
          displayUrl: cbeUrl,
          isAutoConstructed: true,
          note: 'Auto-formatted dashed SMS reference to CBE receipt URL',
          accountSuffix: suffix.isNotEmpty ? suffix : resolveDefaultAccountSuffix('cbe'),
        );
      }

      // If mobile token (16+ alphanumeric with mixed case, e.g. fHCxz62uM8157lCfet)
      final mixedCaseTokenMatch = RegExp(r'\b([A-Za-z0-9]{16,40})\b').firstMatch(raw);
      if (mixedCaseTokenMatch != null &&
          mixedCaseTokenMatch.group(1)!.contains(RegExp(r'[a-z]')) &&
          mixedCaseTokenMatch.group(1)!.contains(RegExp(r'[A-Z0-9]'))) {
        final token = mixedCaseTokenMatch.group(1)!;
        final cbeUrl = 'https://mbreciept.cbe.com.et/$token';
        return ResolvedReceiptInput(
          url: cbeUrl,
          reference: token,
          resolvedBank: 'cbe',
          displayUrl: cbeUrl,
          isAutoConstructed: true,
          note: 'Auto-formatted mobile token to CBE JSON receipt URL',
        );
      }

      // If bare FT reference: e.g. FT26291KVDWY
      final bareFtMatch = RegExp(r'\b(FT[0-9A-Za-z]{8,16})\b', caseSensitive: false).firstMatch(raw);
      if (bareFtMatch != null) {
        final cleanRef = bareFtMatch.group(1)!.toUpperCase();
        final cbeCandidateUrl = 'https://apps.cbe.com.et:100/?id=$cleanRef';
        return ResolvedReceiptInput(
          url: cbeCandidateUrl,
          reference: cleanRef,
          resolvedBank: 'cbe',
          displayUrl: cbeCandidateUrl,
          isAutoConstructed: true,
          note: 'Attempting CBE branch receipt endpoint ($cleanRef). For mobile banking receipts, paste the confirmation SMS link.',
          accountSuffix: resolveDefaultAccountSuffix('cbe'),
        );
      }
    }

    // ── 4. Telebirr ──────────────────────────────────────────────────────────
    if (b == 'telebirr') {
      final sanitized = sanitizeTelebirrReference(raw);
      if (sanitized.startsWith('http://') || sanitized.startsWith('https://')) {
        return ResolvedReceiptInput(
          url: sanitized,
          resolvedBank: 'telebirr',
          displayUrl: sanitized,
        );
      }
      return ResolvedReceiptInput(
        reference: sanitized,
        resolvedBank: 'telebirr',
        displayUrl: sanitized,
      );
    }

    // ── 5. Awash Bank ────────────────────────────────────────────────────────
    if (b == 'awash') {
      if (raw.toLowerCase().contains('awashbank.com')) {
        final cleanUrl = raw.startsWith('http') ? raw : 'https://$raw';
        return ResolvedReceiptInput(
          url: cleanUrl,
          reference: cleanUrl.split('/').last,
          resolvedBank: 'awash',
          displayUrl: cleanUrl,
        );
      }
      final cleanRef = raw
          .replaceAll(RegExp(r'^(?:Ref(?:erence)?|Txn\s*(?:ID|No)|Transaction\s*(?:No|ID|Code)|የግብይት\s*ቁጥር)[\s:]*', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+'), '')
          .trim();
      return ResolvedReceiptInput(
        reference: cleanRef,
        resolvedBank: 'awash',
        displayUrl: cleanRef,
      );
    }

    // ── 6. Dashen Bank ───────────────────────────────────────────────────────
    if (b == 'dashen') {
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        return ResolvedReceiptInput(
          url: raw,
          reference: raw.split('/').last,
          resolvedBank: 'dashen',
          displayUrl: raw,
        );
      }
      final cleanRef = raw
          .replaceAll(RegExp(r'^(?:Ref(?:erence)?|Txn\s*(?:ID|No)|Transaction\s*(?:No|ID|Code)|የግብይት\s*ቁጥር)[\s:]*', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+'), '')
          .trim();
      return ResolvedReceiptInput(
        reference: cleanRef,
        resolvedBank: 'dashen',
        displayUrl: cleanRef,
      );
    }

    // ── 7. CBE Birr ──────────────────────────────────────────────────────────
    if (b == 'cbebirr') {
      final cleanRef = raw
          .replaceAll(RegExp(r'^(?:Receipt\s*(?:No|Number)|Ref(?:erence)?|የደረሰኝ\s*ቁጥር)[\s:]*', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+'), '')
          .trim();
      return ResolvedReceiptInput(
        reference: cleanRef,
        resolvedBank: 'cbebirr',
        displayUrl: cleanRef,
      );
    }

    // ── 6. Other Banks & Universal Fallback ──────────────────────────────────
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return ResolvedReceiptInput(
        url: raw,
        resolvedBank: b.isEmpty ? 'universal' : b,
        displayUrl: raw,
      );
    }

    return ResolvedReceiptInput(
      reference: raw,
      resolvedBank: b.isEmpty ? 'universal' : b,
      displayUrl: raw,
    );
  }

  /// Verifies a single Ethiopian payment receipt via Verify.ET (POST /api/verify).
  /// Works across Telebirr, CBE, Bank of Abyssinia, Awash, Dashen, CBE Birr, M-Pesa, Siinqee, etc.
  Future<LinksEtResult> verifyReceipt({
    String? url,
    String? reference,
    String? rawInput,
    String? bankHint,
    String? accountSuffix,
    String? senderAccount,
    String? phone,
    String? settlementAccount,
    int waitMs = 8000,
    bool autoPoll = true,
    void Function(int attempt, int maxAttempts)? onPollTick,
  }) async {
    if (!hasApiKey) {
      throw Exception(
        'Verify.ET API Key is missing. Please configure it in settings.',
      );
    }

    var trimmedUrl = url?.trim();
    var trimmedRef = reference?.trim();
    final cleanBank = (bankHint ?? '').toLowerCase().trim();

    // Auto-resolve raw user input across banks (CBE, BOA, Telebirr, etc.)
    if (rawInput != null && rawInput.trim().isNotEmpty) {
      final resolved = resolveReceiptInput(
        input: rawInput,
        bank: cleanBank,
      );
      trimmedUrl = resolved.url;
      trimmedRef = resolved.reference;
    }

    // Auto-uppercase bank reference tokens (FT... for CBE/BOA)
    if (trimmedRef != null &&
        (trimmedRef.toUpperCase().startsWith('FT') || cleanBank == 'cbe' || cleanBank == 'boa')) {
      trimmedRef = trimmedRef.toUpperCase();
    }

    if ((trimmedUrl == null || trimmedUrl.isEmpty) &&
        (trimmedRef == null || trimmedRef.isEmpty)) {
      throw Exception(
        'Either a receipt URL or a transaction reference number is required.',
      );
    }

    final targetId = (trimmedRef != null && trimmedRef.isNotEmpty)
        ? trimmedRef
        : trimmedUrl!;
    final previousRecord = scannedStorage.findRecord(targetId);

    // Build payload according to Verify.ET API specs (https://verify.et/docs/api)
    final payload = <String, dynamic>{};
    final clampedWait = waitMs.clamp(500, 30000);
    payload['waitMs'] = clampedWait;

    if (cleanBank.isNotEmpty && cleanBank != 'universal') {
      payload['bank'] = cleanBank;
    }

    final targetRef = (trimmedRef != null && trimmedRef.isNotEmpty)
        ? trimmedRef
        : (trimmedUrl ?? '');

    // Set common reference keys for maximum API compatibility
    payload['reference'] = targetRef;
    payload['referenceNumber'] = targetRef;

    // Filter out internal non-API URLs (like apps.cbe.com.et:100) from being sent as 'url'
    final isOfficialWebReceiptUrl = trimmedUrl != null &&
        trimmedUrl.isNotEmpty &&
        !trimmedUrl.contains('apps.cbe.com.et:100');

    if (isOfficialWebReceiptUrl) {
      payload['url'] = trimmedUrl;
    }

    if (cleanBank == 'telebirr' || cleanBank == 'mpesa') {
      final cleanTok = sanitizeTelebirrReference(targetRef);
      final ref = cleanTok.isNotEmpty ? cleanTok : targetRef;
      payload['transactionNumber'] = ref;
      payload['reference'] = ref;
      payload['referenceNumber'] = ref;
      if (phone != null && phone.trim().isNotEmpty) {
        payload['phone'] = phone.trim();
        payload['phoneNumber'] = phone.trim();
      }
    } else if (cleanBank == 'cbebirr') {
      payload['receiptNumber'] = targetRef;
      payload['reference'] = targetRef;
      payload['referenceNumber'] = targetRef;
      if (phone != null && phone.trim().isNotEmpty) {
        payload['phone'] = phone.trim();
        payload['phoneNumber'] = phone.trim();
      }
    } else if (cleanBank == 'boa') {
      final effRef = targetRef.toUpperCase().startsWith('FT') ? targetRef.toUpperCase() : targetRef;
      payload['reference'] = effRef;
      payload['referenceNumber'] = effRef;
      // BOA strictly requires 5-digit accountSuffix (indexes by sender's debited account on transfers)
      final rawSuffix = (accountSuffix != null && accountSuffix.trim().isNotEmpty)
          ? accountSuffix.trim()
          : (senderAccount != null && senderAccount.trim().isNotEmpty
              ? senderAccount.trim()
              : resolveDefaultAccountSuffix('boa'));
      final effSuffix = sanitizeAccountSuffix(rawSuffix, 'boa');
      if (effSuffix.isNotEmpty) {
        payload['accountSuffix'] = effSuffix;
        payload['suffix'] = effSuffix;
      }
    } else if (cleanBank == 'cbe') {
      final effRef = targetRef.toUpperCase().startsWith('FT') ? targetRef.toUpperCase() : targetRef;
      payload['reference'] = effRef;
      payload['referenceNumber'] = effRef;
      // CBE strictly requires 8-digit accountSuffix
      final rawSuffix = (accountSuffix != null && accountSuffix.trim().isNotEmpty)
          ? accountSuffix.trim()
          : (effRef.toUpperCase().startsWith('FT') ? resolveDefaultAccountSuffix('cbe') : '');
      final effSuffix = sanitizeAccountSuffix(rawSuffix, 'cbe');
      if (effSuffix.isNotEmpty) {
        payload['accountSuffix'] = effSuffix;
        payload['suffix'] = effSuffix;
      }
    } else {
      if (accountSuffix != null && accountSuffix.trim().isNotEmpty) {
        payload['accountSuffix'] = accountSuffix.trim();
        payload['suffix'] = accountSuffix.trim();
      }
      if (phone != null && phone.trim().isNotEmpty) {
        payload['phone'] = phone.trim();
        payload['phoneNumber'] = phone.trim();
      }
    }

    // Default settlementAccount based on bank if not explicitly passed
    final effSettlement = (settlementAccount != null && settlementAccount.trim().isNotEmpty)
        ? settlementAccount.trim()
        : resolveDefaultSettlementAccount(cleanBank);
    if (effSettlement.isNotEmpty) {
      payload['settlementAccount'] = effSettlement;
    }

    final idKey =
        'v_${ScannedReceiptStorage.normalizeId(targetId)}_${DateTime.now().millisecondsSinceEpoch}';

    final uri = Uri.parse('$defaultBaseUrl/api/verify?waitMs=$clampedWait');
    final res = await http.post(
      uri,
      headers: _buildHeaders(idempotencyKey: idKey),
      body: jsonEncode(payload),
    );

    var result = _handleVerificationResponse(
      res,
      previousRecord: previousRecord,
    );

    // If BOA verification failed with not_found, but a distinct sender account is available, retry with sender suffix
    if (cleanBank == 'boa' &&
        !result.verified &&
        senderAccount != null &&
        senderAccount.trim().isNotEmpty) {
      final senderSuffix = sanitizeAccountSuffix(senderAccount, 'boa');
      if (senderSuffix.isNotEmpty && senderSuffix != payload['accountSuffix']) {
        final retryPayload = Map<String, dynamic>.from(payload);
        retryPayload['accountSuffix'] = senderSuffix;
        retryPayload['suffix'] = senderSuffix;

        try {
          final retryRes = await http.post(
            uri,
            headers: _buildHeaders(idempotencyKey: '${idKey}_snd'),
            body: jsonEncode(retryPayload),
          );
          final retryResult = _handleVerificationResponse(
            retryRes,
            previousRecord: previousRecord,
          );
          if (retryResult.verified || retryResult.isSuccess) {
            result = retryResult;
          }
        } catch (_) {}
      }
    }

    // If HTTP 202 queued and autoPoll is requested, poll until completion
    if (autoPoll &&
        result.isPending &&
        result.requestId != null &&
        result.requestId!.isNotEmpty) {
      result = await _pollUntilComplete(
        result.requestId!,
        initialResult: result,
        onPollTick: onPollTick,
      );
    }

    // If verification succeeded at the bank, store to local database
    if (result.isSuccess && (result.receipt != null || result.verified)) {
      final method = result.bank.isNotEmpty
          ? result.bank
          : (bankHint ?? 'universal');
      final recordId = result.referenceNumber ??
          result.receipt?.reference ??
          targetId;

      final saved = scannedStorage.saveRecord(
        id: recordId,
        method: method,
        status: 'verified',
        amount: result.amount > 0 ? result.amount : result.receipt?.amount,
        currency: result.currency,
        payerName: result.senderName ?? result.receipt?.payerName,
        payerAccount: result.receipt?.payerAccount,
        receiverName: result.receiverName ?? result.receipt?.receiverName,
        receiverAccount: result.receiverAccount ?? result.receipt?.receiverAccount,
        receiptUrl: result.resolvedUrl ?? trimmedUrl,
      );
      result = result.copyWith(previousRecord: saved);
    }

    return result;
  }

  /// Verifies a receipt screenshot via Verify.ET multipart form data (POST /api/verify).
  /// Accepts JPEG, PNG, or WebP up to 8 MB. Reads embedded QR codes and printed receipt fields.
  Future<LinksEtResult> verifyScreenshot({
    required Uint8List imageBytes,
    String? fileName,
    String? bankHint,
    String? reference,
    String? accountSuffix,
    String? phone,
    int waitMs = 8000,
    bool autoPoll = true,
    void Function(int attempt, int maxAttempts)? onPollTick,
  }) async {
    if (!hasApiKey) {
      throw Exception(
        'Verify.ET API Key is missing. Please configure it in settings.',
      );
    }

    final clampedWait = waitMs.clamp(500, 30000);
    final uri = Uri.parse('$defaultBaseUrl/api/verify?waitMs=$clampedWait');
    final idKey = 'img_${DateTime.now().millisecondsSinceEpoch}';

    final request = http.MultipartRequest('POST', uri);
    request.headers['x-api-key'] = apiKey.value.trim();
    request.headers['Idempotency-Key'] = idKey;
    request.headers['Accept'] = 'application/json';

    final cleanBank = (bankHint ?? '').toLowerCase().trim();
    if (cleanBank.isNotEmpty && cleanBank != 'universal') {
      request.fields['bank'] = cleanBank;
    }
    if (reference != null && reference.trim().isNotEmpty) {
      final ref = reference.trim();
      final effRef = (ref.toUpperCase().startsWith('FT') || cleanBank == 'cbe' || cleanBank == 'boa')
          ? ref.toUpperCase()
          : ref;
      request.fields['reference'] = effRef;
      request.fields['referenceNumber'] = effRef;
    }
    final rawSuffix = (accountSuffix != null && accountSuffix.trim().isNotEmpty)
        ? accountSuffix.trim()
        : (cleanBank == 'boa'
            ? resolveDefaultAccountSuffix('boa')
            : (cleanBank == 'cbe' ? resolveDefaultAccountSuffix('cbe') : ''));
    final effSuffix = sanitizeAccountSuffix(rawSuffix, cleanBank);
    if (effSuffix.isNotEmpty) {
      request.fields['accountSuffix'] = effSuffix;
      request.fields['suffix'] = effSuffix;
    }
    if (phone != null && phone.trim().isNotEmpty) {
      request.fields['phone'] = phone.trim();
      request.fields['phoneNumber'] = phone.trim();
    }
    final effSettlement = resolveDefaultSettlementAccount(cleanBank);
    if (effSettlement.isNotEmpty) {
      request.fields['settlementAccount'] = effSettlement;
    }

    final name = fileName ?? 'receipt.jpg';
    final ext = name.split('.').last.toLowerCase();
    String mimeType = 'image/jpeg';
    if (ext == 'png') {
      mimeType = 'image/png';
    } else if (ext == 'webp') {
      mimeType = 'image/webp';
    }

    final multipartFile = http.MultipartFile.fromBytes(
      'image',
      imageBytes,
      filename: name,
      contentType: MediaType.parse(mimeType),
    );
    request.files.add(multipartFile);

    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);

    var result = _handleVerificationResponse(res);

    if (autoPoll &&
        result.isPending &&
        result.requestId != null &&
        result.requestId!.isNotEmpty) {
      result = await _pollUntilComplete(
        result.requestId!,
        initialResult: result,
        onPollTick: onPollTick,
      );
    }

    // Check if detected token was previously verified
    final detectedToken = result.referenceNumber ??
        result.detected?.reference ??
        result.detected?.url;
    final prev = scannedStorage.findRecord(detectedToken);
    result = result.copyWith(previousRecord: prev);

    // If verified successfully upstream, store in local database
    final bankReceipt = result.receipt ?? result.upstream?.result?.receipt;
    if (result.isSuccess && (bankReceipt != null || result.verified)) {
      final method = result.bank.isNotEmpty ? result.bank : (bankHint ?? 'universal');
      final recordId = result.referenceNumber ??
          detectedToken ??
          'receipt_${DateTime.now().millisecondsSinceEpoch}';

      final saved = scannedStorage.saveRecord(
        id: recordId,
        method: method,
        status: 'verified',
        amount: result.amount > 0 ? result.amount : bankReceipt?.amount,
        currency: result.currency,
        payerName: result.senderName ?? bankReceipt?.payerName,
        payerAccount: bankReceipt?.payerAccount,
        receiverName: result.receiverName ?? bankReceipt?.receiverName,
        receiverAccount: bankReceipt?.receiverAccount,
        receiptUrl: result.resolvedUrl ?? result.detected?.url,
      );
      result = result.copyWith(previousRecord: saved);
    }

    return result;
  }

  /// Checks the status of an asynchronous or queued verification via GET /api/verify/:requestId.
  Future<LinksEtResult> getVerificationStatus(String requestId) async {
    if (!hasApiKey) {
      throw Exception(
        'Verify.ET API Key is missing. Please configure it in settings.',
      );
    }

    final cleanId = requestId.trim();
    final uri = Uri.parse('$defaultBaseUrl/api/verify/$cleanId');
    final res = await http.get(
      uri,
      headers: {'x-api-key': apiKey.value.trim(), 'Accept': 'application/json'},
    );

    return _handleVerificationResponse(res);
  }

  /// Polls the status endpoint until the verification is completed or max attempts reached.
  Future<LinksEtResult> _pollUntilComplete(
    String requestId, {
    LinksEtResult? initialResult,
    int maxAttempts = 12,
    void Function(int attempt, int maxAttempts)? onPollTick,
  }) async {
    var latest = initialResult ?? await getVerificationStatus(requestId);
    if (!latest.isPending) return latest;

    for (int i = 1; i <= maxAttempts; i++) {
      onPollTick?.call(i, maxAttempts);
      await Future.delayed(const Duration(milliseconds: 2000));

      try {
        final current = await getVerificationStatus(requestId);
        latest = current;
        if (!current.isPending) {
          return current;
        }
      } catch (e) {
        debugPrint('[VerifyEtService] Status poll attempt $i: $e');
      }
    }

    return latest;
  }

  /// Parses the API envelope from Verify.ET (POST /api/verify and GET /api/verify/:requestId).
  LinksEtResult _handleVerificationResponse(
    http.Response res, {
    ScannedReceiptRecord? previousRecord,
  }) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception(
        'Failed to parse Verify.ET response (HTTP ${res.statusCode}): ${res.body}',
      );
    }

    if (res.statusCode == 200 || res.statusCode == 202) {
      return LinksEtResult.fromJson(body, previousRecord: previousRecord);
    }

    // 502: parsed upstream but didn't validate as official receipt
    if (res.statusCode == 502) {
      return LinksEtResult.fromJson(body, previousRecord: previousRecord);
    }

    // Specific Verify.ET error handling
    final rawErr = body['error'];
    String errCode = '';
    String errMsg = '';

    if (rawErr is Map) {
      errCode = rawErr['code']?.toString() ?? '';
      errMsg = rawErr['message']?.toString() ?? '';
    } else if (rawErr is String) {
      errMsg = rawErr;
    } else {
      errMsg = body['message']?.toString() ?? 'HTTP ${res.statusCode} Error';
    }

    if (res.statusCode == 401) {
      throw Exception(
        'Verify.ET Unauthorized ($errCode): Invalid or missing x-api-key. Please verify your key.',
      );
    } else if (res.statusCode == 403) {
      if (errCode == 'IMAGE_PROCESSING_DISABLED') {
        throw Exception(
          'Image Processing is disabled on your Verify.ET account. Please enable Image Processing in the Verify.ET dashboard (https://verify.et) or enter the transaction reference directly.',
        );
      }
      throw Exception('Verify.ET Permission Denied: $errMsg (verification:write required)');
    } else if (res.statusCode == 402) {
      if (errCode == 'INSUFFICIENT_IMAGE_CREDITS') {
        throw Exception(
          'Verify.ET Image Processing credit allowance reached. Please top up image credits or enter the reference manually.',
        );
      }
      throw Exception(
        'Verify.ET Insufficient Credits: Your verification credit balance has been reached.',
      );
    } else if (res.statusCode == 429) {
      throw Exception(
        'Verify.ET Rate Limited: Too many requests. Please wait a moment before retrying.',
      );
    } else if (res.statusCode == 422) {
      if (errCode == 'IMAGE_UNREADABLE') {
        throw Exception(
          'Receipt image could not be decoded or read by QR/OCR. Please enter transaction reference or upload a clearer screenshot.',
        );
      }
      throw Exception('Invalid verification payload: $errMsg');
    } else if (res.statusCode == 400) {
      throw Exception('Verify.ET Request Error: $errMsg');
    }

    throw Exception(
      errMsg.isNotEmpty ? errMsg : 'Verify.ET error (${res.statusCode})',
    );
  }

  /// Fetches verification history from live Verify.ET cloud platform (GET /api/verify/history)
  /// and merges with local app database records.
  Future<List<VerifyEtHistoryItem>> fetchHistory({
    String? bank,
    String? status,
  }) async {
    final localRecords = scannedStorage.getAllRecords();
    var filteredLocal = localRecords;
    if (bank != null && bank.isNotEmpty && bank != 'all') {
      filteredLocal = filteredLocal
          .where((r) => r.method.toLowerCase() == bank.toLowerCase())
          .toList();
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      filteredLocal = filteredLocal
          .where((r) => r.status.toLowerCase() == status.toLowerCase())
          .toList();
    }

    final localItems = filteredLocal
        .map((r) => VerifyEtHistoryItem.fromScannedRecord(r))
        .toList();

    // If API key is configured, also fetch from Verify.ET remote history endpoint
    if (hasApiKey) {
      try {
        final queryParams = <String, String>{
          'limit': '50',
          if (bank != null && bank.isNotEmpty && bank != 'all') 'bank': bank,
          if (status != null && status.isNotEmpty && status != 'all') 'status': status,
        };
        final uri = Uri.parse('$defaultBaseUrl/api/verify/history')
            .replace(queryParameters: queryParams);
        final res = await http.get(
          uri,
          headers: {'x-api-key': apiKey.value.trim(), 'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          if (body['data'] is List) {
            final remoteList = (body['data'] as List)
                .whereType<Map>()
                .map((m) => VerifyEtHistoryItem.fromJson(Map<String, dynamic>.from(m)))
                .toList();

            final seenKeys = <String>{};
            final merged = <VerifyEtHistoryItem>[];

            for (final r in remoteList) {
              final key = ScannedReceiptStorage.normalizeId(r.referenceNumber ?? r.requestId);
              seenKeys.add(key);

              // Enrich with local scan information (email, scan count, approval time) if available
              final localMatch = scannedStorage.findRecord(key);
              if (localMatch != null && localMatch.userEmail != null) {
                merged.add(VerifyEtHistoryItem(
                  requestId: r.requestId,
                  referenceNumber: r.referenceNumber,
                  bank: r.bank,
                  processingStatus: r.processingStatus,
                  status: r.status,
                  verified: r.verified,
                  amount: r.amount > 0 ? r.amount : (localMatch.amount ?? 0.0),
                  currency: r.currency,
                  createdAt: r.createdAt ?? localMatch.scannedAt,
                  scanCount: localMatch.scanCount,
                  previousScannedAt: localMatch.previousScannedAt,
                  userEmail: localMatch.userEmail,
                  senderName: r.senderName ?? localMatch.payerName,
                  receiverName: r.receiverName ?? localMatch.receiverName,
                ));
              } else {
                merged.add(r);
              }
            }

            for (final l in localItems) {
              final key = ScannedReceiptStorage.normalizeId(l.referenceNumber ?? l.requestId);
              if (!seenKeys.contains(key)) {
                merged.add(l);
                seenKeys.add(key);
              }
            }

            return merged;
          }
        }
      } catch (e) {
        debugPrint('[VerifyEtService] Remote history fetch fallback: $e');
      }
    }

    return localItems;
  }

  /// Legacy compatibility wrapper for verifyTransaction.
  Future<LinksEtResult> verifyTransaction({
    String? bank,
    required String reference,
    String? accountSuffix,
    String? phone,
    String? settlementAccount,
    int waitMs = 5000,
    bool autoPoll = true,
    void Function(int attempt, int maxAttempts)? onPollTick,
  }) {
    return verifyReceipt(
      reference: reference,
      url: reference.startsWith('http') ? reference : null,
      bankHint: bank,
      accountSuffix: accountSuffix,
      phone: phone,
      settlementAccount: settlementAccount,
      waitMs: waitMs,
      autoPoll: autoPoll,
      onPollTick: onPollTick,
    );
  }

  /// Legacy compatibility wrapper for verifyReceiptImage.
  Future<LinksEtResult> verifyReceiptImage({
    required Uint8List imageBytes,
    required String fileName,
    String? bank,
    String? reference,
    String? accountSuffix,
    String? phone,
    String? settlementAccount,
    int waitMs = 5000,
    bool autoPoll = true,
    void Function(int attempt, int maxAttempts)? onPollTick,
  }) {
    return verifyScreenshot(
      imageBytes: imageBytes,
      fileName: fileName,
      bankHint: bank,
      reference: reference,
      accountSuffix: accountSuffix,
      phone: phone,
      waitMs: waitMs,
      autoPoll: autoPoll,
      onPollTick: onPollTick,
    );
  }
}

/// Backward compatibility alias so existing `Get.find<LinksEtService>()` works identically.
typedef LinksEtService = VerifyEtService;

/// Represents a normalized and resolved receipt input for the Verify.ET API.
class ResolvedReceiptInput {
  /// The full receipt URL to submit to Verify.ET (if verifying by URL).
  final String? url;

  /// The reference code or token (if verifying by reference).
  final String? reference;

  /// The resolved or normalized bank key ('telebirr', 'cbe', 'boa', 'awash', 'dashen', 'zemen', etc.).
  final String resolvedBank;

  /// Whether the URL or reference was automatically constructed from a raw reference / token / SMS.
  final bool isAutoConstructed;

  /// A clean display version of the target for user-facing toasts or status indicators.
  final String? displayUrl;

  /// Helpful guidance or contextual note about the resolution.
  final String? note;

  /// Optional account suffix required for certain banks (e.g. 5 digits for BOA, 8 for CBE).
  final String? accountSuffix;

  /// Optional phone number for wallet-based banks (e.g. CBE Birr, Telebirr).
  final String? phone;

  const ResolvedReceiptInput({
    this.url,
    this.reference,
    required this.resolvedBank,
    this.isAutoConstructed = false,
    this.displayUrl,
    this.note,
    this.accountSuffix,
    this.phone,
  });

  bool get isTelebirrShorthand =>
      resolvedBank == 'telebirr' && reference != null && reference!.isNotEmpty;

  String get primaryTarget => (reference != null && reference!.isNotEmpty)
      ? reference!
      : (url ?? '');
}
