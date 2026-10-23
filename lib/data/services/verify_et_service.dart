import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:m_admin/features/payments/models/verify_et_model.dart';

class VerifyEtService extends GetxService {
  static VerifyEtService get instance =>
      Get.isRegistered<VerifyEtService>()
          ? Get.find<VerifyEtService>()
          : Get.put(VerifyEtService(), permanent: true);

  static const String defaultBaseUrl = 'https://verify.et';
  static const String _kApiKeyStorageKey = 'verify_et_api_key';
  static const String _kDefaultSettlementKey = 'verify_et_default_settlement';

  final apiKey = ''.obs;
  final defaultSettlementAccount = ''.obs;

  @override
  void onInit() {
    super.onInit();
    String? storedKey;
    String? storedSettlement;
    try {
      final box = GetStorage();
      storedKey = box.read<String>(_kApiKeyStorageKey)?.trim();
      storedSettlement = box.read<String>(_kDefaultSettlementKey)?.trim();
    } catch (_) {}

    String? envKey;
    try {
      envKey = dotenv.env['VERIFY_ET_API_KEY']?.trim();
    } catch (_) {}

    apiKey.value = (storedKey != null && storedKey.isNotEmpty)
        ? storedKey
        : (envKey ?? '');

    defaultSettlementAccount.value = storedSettlement ?? '';
  }

  bool get hasApiKey => apiKey.value.trim().isNotEmpty;

  void saveApiKey(String newKey) {
    final trimmed = newKey.trim();
    apiKey.value = trimmed;
    try {
      GetStorage().write(_kApiKeyStorageKey, trimmed);
    } catch (_) {}
  }

  void saveDefaultSettlementAccount(String acc) {
    final trimmed = acc.trim();
    defaultSettlementAccount.value = trimmed;
    try {
      GetStorage().write(_kDefaultSettlementKey, trimmed);
    } catch (_) {}
  }

  Map<String, String> _buildHeaders({String? idempotencyKey}) {
    final key = apiKey.value.trim();
    return {
      'x-api-key': key,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Idempotency-Key': idempotencyKey ?? 'req_${DateTime.now().millisecondsSinceEpoch}',
    };
  }

  /// Helper to extract numeric suffix digits from an account string
  String? _deriveSuffix(String? account, int length) {
    if (account == null) return null;
    final digits = account.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= length) {
      return digits.substring(digits.length - length);
    }
    return digits.isNotEmpty ? digits : null;
  }

  /// Submits an instant bank receipt/transaction verification to Verify.ET.
  /// Automatically polls GET /api/verify/:requestId if the bank queues verification (e.g. Telebirr).
  Future<VerifyEtResult> verifyTransaction({
    String? bank,
    required String reference,
    String? accountSuffix,
    String? phone,
    String? settlementAccount,
    int waitMs = 5000,
    bool autoPoll = true,
    void Function(int attempt, int maxAttempts)? onPollTick,
  }) async {
    if (!hasApiKey) {
      throw Exception('Verify.ET API Key is missing. Please configure it in the settings below.');
    }

    final uri = Uri.parse('$defaultBaseUrl/api/verify?waitMs=$waitMs');
    final payload = <String, dynamic>{};

    final effectiveSettlement = (settlementAccount != null && settlementAccount.trim().isNotEmpty)
        ? settlementAccount.trim()
        : (defaultSettlementAccount.value.isNotEmpty ? defaultSettlementAccount.value : null);

    if (effectiveSettlement != null) {
      payload['settlementAccount'] = effectiveSettlement;
    }

    final trimmedRef = reference.trim();
    final cleanBank = bank?.toLowerCase().trim();

    if (cleanBank == null || cleanBank.isEmpty || cleanBank == 'universal') {
      // Universal router: reference field auto-detects CBE receipt ID, links, or tokens
      payload['reference'] = trimmedRef;
      payload['referenceNumber'] = trimmedRef;

      final effSuffix = (accountSuffix != null && accountSuffix.trim().isNotEmpty)
          ? accountSuffix.trim()
          : (trimmedRef.toUpperCase().startsWith('FT') ? _deriveSuffix(effectiveSettlement, 8) : null);

      if (effSuffix != null && effSuffix.isNotEmpty) {
        payload['accountSuffix'] = effSuffix;
        payload['suffix'] = effSuffix;
      }
      if (phone != null && phone.trim().isNotEmpty) {
        payload['phone'] = phone.trim();
        payload['phoneNumber'] = phone.trim();
      }
    } else {
      payload['bank'] = cleanBank;

      switch (cleanBank) {
        case 'cbe':
          payload['reference'] = trimmedRef;
          payload['referenceNumber'] = trimmedRef;
          // CBE older FT references require 8-digit suffix; receipt URLs / IDs do not.
          final isCbeFt = trimmedRef.toUpperCase().startsWith('FT');
          final effSuffix = (accountSuffix != null && accountSuffix.trim().isNotEmpty)
              ? accountSuffix.trim()
              : (isCbeFt ? _deriveSuffix(effectiveSettlement, 8) : null);
          if (effSuffix != null && effSuffix.isNotEmpty) {
            payload['accountSuffix'] = effSuffix;
            payload['suffix'] = effSuffix;
          }
          break;

        case 'boa':
          payload['reference'] = trimmedRef;
          payload['referenceNumber'] = trimmedRef;
          final effSuffix = (accountSuffix != null && accountSuffix.trim().isNotEmpty)
              ? accountSuffix.trim()
              : _deriveSuffix(effectiveSettlement, 5);
          if (effSuffix != null && effSuffix.isNotEmpty) {
            payload['accountSuffix'] = effSuffix;
            payload['suffix'] = effSuffix;
          }
          break;

        case 'telebirr':
        case 'mpesa':
          payload['transactionNumber'] = trimmedRef;
          payload['reference'] = trimmedRef;
          payload['referenceNumber'] = trimmedRef;
          break;

        case 'cbebirr':
          payload['receiptNumber'] = trimmedRef;
          payload['reference'] = trimmedRef;
          payload['referenceNumber'] = trimmedRef;
          if (phone != null && phone.trim().isNotEmpty) {
            payload['phone'] = phone.trim();
            payload['phoneNumber'] = phone.trim();
          }
          break;

        case 'coopayebirr':
        case 'oromia':
        case 'coop':
        case 'cbo':
          payload['bank'] = 'coopayebirr';
          payload['reference'] = trimmedRef;
          payload['referenceNumber'] = trimmedRef;
          if (phone != null && phone.trim().isNotEmpty) {
            payload['phone'] = phone.trim();
            payload['phoneNumber'] = phone.trim();
          }
          break;

        case 'awash':
          payload['bank'] = 'awash';
          payload['reference'] = trimmedRef;
          payload['referenceNumber'] = trimmedRef;
          if (phone != null && phone.trim().isNotEmpty) {
            payload['phone'] = phone.trim();
            payload['phoneNumber'] = phone.trim();
          }
          break;

        case 'dashen':
        case 'siinqee':
        case 'kaafiebirr':
        default:
          payload['reference'] = trimmedRef;
          payload['referenceNumber'] = trimmedRef;
          if (phone != null && phone.trim().isNotEmpty) {
            payload['phone'] = phone.trim();
            payload['phoneNumber'] = phone.trim();
          }
          break;
      }
    }

    final res = await http.post(
      uri,
      headers: _buildHeaders(idempotencyKey: 'v_${cleanBank ?? 'uni'}_${trimmedRef}_${DateTime.now().millisecondsSinceEpoch}'),
      body: jsonEncode(payload),
    );

    final rawResult = _handleVerificationResponse(res);

    // If result was queued (HTTP 202) and autoPoll is requested, poll until completion
    if (autoPoll && rawResult.isPending && rawResult.requestId != null && rawResult.requestId!.isNotEmpty) {
      return await _pollUntilComplete(
        rawResult.requestId!,
        initialResult: rawResult,
        pollAfterMs: rawResult.pollAfterMs,
        onPollTick: onPollTick,
      );
    }

    return rawResult;
  }

  /// Uploads a receipt image (JPEG, PNG, WebP) to Verify.ET for automated QR & OCR verification.
  /// Automatically polls GET /api/verify/:requestId if queued.
  Future<VerifyEtResult> verifyReceiptImage({
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
  }) async {
    if (!hasApiKey) {
      throw Exception('Verify.ET API Key is missing. Please configure it in the settings below.');
    }

    final uri = Uri.parse('$defaultBaseUrl/api/verify?waitMs=$waitMs');
    final req = http.MultipartRequest('POST', uri);

    final idempotencyKey = 'img_${DateTime.now().millisecondsSinceEpoch}';
    req.headers['x-api-key'] = apiKey.value.trim();
    req.headers['Idempotency-Key'] = idempotencyKey;
    req.headers['Accept'] = 'application/json';

    req.files.add(http.MultipartFile.fromBytes(
      'image',
      imageBytes,
      filename: fileName,
    ));

    final effectiveSettlement = (settlementAccount != null && settlementAccount.trim().isNotEmpty)
        ? settlementAccount.trim()
        : (defaultSettlementAccount.value.isNotEmpty ? defaultSettlementAccount.value : null);

    if (effectiveSettlement != null) {
      req.fields['settlementAccount'] = effectiveSettlement;
    }

    final cleanBank = bank != null && bank.isNotEmpty && bank != 'universal'
        ? bank.toLowerCase().trim()
        : null;

    if (cleanBank != null) {
      req.fields['bank'] = cleanBank;
    }
    if (reference != null && reference.trim().isNotEmpty) {
      final refTrim = reference.trim();
      req.fields['reference'] = refTrim;
      req.fields['referenceNumber'] = refTrim;
      if (cleanBank == 'telebirr' || cleanBank == 'mpesa') {
        req.fields['transactionNumber'] = refTrim;
      } else if (cleanBank == 'cbebirr') {
        req.fields['receiptNumber'] = refTrim;
      }
    }

    // Suffix resolution
    final effSuffix = (accountSuffix != null && accountSuffix.trim().isNotEmpty)
        ? accountSuffix.trim()
        : (cleanBank == 'cbe'
            ? _deriveSuffix(effectiveSettlement, 8)
            : (cleanBank == 'boa' ? _deriveSuffix(effectiveSettlement, 5) : null));

    if (effSuffix != null && effSuffix.isNotEmpty) {
      req.fields['accountSuffix'] = effSuffix;
      req.fields['suffix'] = effSuffix;
    }

    if (phone != null && phone.trim().isNotEmpty) {
      req.fields['phone'] = phone.trim();
      req.fields['phoneNumber'] = phone.trim();
    }

    final streamedRes = await req.send();
    final res = await http.Response.fromStream(streamedRes);

    final rawResult = _handleVerificationResponse(res);

    if (autoPoll && rawResult.isPending && rawResult.requestId != null && rawResult.requestId!.isNotEmpty) {
      return await _pollUntilComplete(
        rawResult.requestId!,
        initialResult: rawResult,
        pollAfterMs: rawResult.pollAfterMs,
        onPollTick: onPollTick,
      );
    }

    return rawResult;
  }

  /// Fetches the latest verification status for a specific requestId from GET /api/verify/:requestId.
  Future<VerifyEtResult> getVerificationStatus(String requestId) async {
    if (!hasApiKey) {
      throw Exception('Verify.ET API Key is missing. Please configure it in the settings below.');
    }

    final cleanId = requestId.trim();
    final uri = Uri.parse('$defaultBaseUrl/api/verify/$cleanId');
    final res = await http.get(uri, headers: {
      'x-api-key': apiKey.value.trim(),
      'Accept': 'application/json',
    });

    if (res.statusCode == 200) {
      Map<String, dynamic> body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception('Failed to parse status response: ${res.body}');
      }

      final data = body['data'];
      if (data is Map<String, dynamic>) {
        return VerifyEtResult.fromJson(data, requestId: cleanId);
      } else if (data is List && data.isNotEmpty && data.first is Map) {
        return VerifyEtResult.fromJson(data.first as Map<String, dynamic>, requestId: cleanId);
      } else if (body['verification'] is Map<String, dynamic>) {
        return VerifyEtResult.fromJson(body['verification'] as Map<String, dynamic>, requestId: cleanId);
      }
      return VerifyEtResult.fromJson(body, requestId: cleanId);
    } else if (res.statusCode == 202) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return _buildPendingResult(body, requestId: cleanId);
    } else {
      Map<String, dynamic>? body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
      final errorMsg = body?['message']?.toString() ??
          body?['error']?['message']?.toString() ??
          'Failed to check status (HTTP ${res.statusCode})';
      throw Exception(errorMsg);
    }
  }

  /// Polls the status endpoint until the verification is completed or max attempts reached.
  Future<VerifyEtResult> _pollUntilComplete(
    String requestId, {
    VerifyEtResult? initialResult,
    int? pollAfterMs,
    int maxAttempts = 6,
    void Function(int attempt, int maxAttempts)? onPollTick,
  }) async {
    var latest = initialResult ?? await getVerificationStatus(requestId);
    if (!latest.isPending) return latest;

    final delayMs = pollAfterMs ?? latest.pollAfterMs ?? 1500;

    for (int i = 1; i <= maxAttempts; i++) {
      onPollTick?.call(i, maxAttempts);
      await Future.delayed(Duration(milliseconds: delayMs));

      try {
        final current = await getVerificationStatus(requestId);
        latest = current;
        if (!current.isPending) {
          return current;
        }
      } catch (e) {
        // Transient network issue while polling; continue to next poll cycle
        debugPrint('[VerifyEtService] Status poll attempt $i encountered: $e');
      }
    }

    return latest;
  }

  /// Constructs a pending VerifyEtResult from a 202 Accepted response.
  VerifyEtResult _buildPendingResult(Map<String, dynamic> body, {String? requestId}) {
    final reqId = requestId ??
        body['requestId']?.toString() ??
        body['verification']?['requestId']?.toString();
    final status = body['verification']?['status']?.toString() ?? 'pending';
    final links = body['links'] is Map<String, dynamic> ? body['links'] as Map<String, dynamic> : null;
    final pollAfterMs = (links?['pollAfterMs'] as num?)?.toInt() ?? 1500;
    final statusUrl = links?['statusUrl']?.toString() ?? body['statusUrl']?.toString();
    final estWaitMs = (body['estimatedWaitMs'] as num?)?.toInt() ?? 5000;

    return VerifyEtResult(
      bank: body['verification']?['bank']?.toString() ?? 'unknown',
      status: status,
      verified: false,
      amount: 0.0,
      currency: 'ETB',
      requestId: reqId,
      processingStatus: body['verification']?['processingStatus']?.toString() ?? 'queued',
      statusUrl: statusUrl,
      pollAfterMs: pollAfterMs,
      estimatedWaitMs: estWaitMs,
      rawJson: body,
    );
  }

  /// Parses the API envelope from Verify.ET.
  VerifyEtResult _handleVerificationResponse(http.Response res) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Failed to parse response from Verify.ET (HTTP ${res.statusCode}): ${res.body}');
    }

    if (res.statusCode == 200) {
      final dataList = body['data'];
      final requestId = body['requestId']?.toString();
      ImageProcessingInfo? imgInfo;
      if (body['imageProcessing'] is Map<String, dynamic>) {
        imgInfo = ImageProcessingInfo.fromJson(body['imageProcessing'] as Map<String, dynamic>);
      }

      if (dataList is List && dataList.isNotEmpty && dataList.first is Map) {
        return VerifyEtResult.fromJson(
          dataList.first as Map<String, dynamic>,
          requestId: requestId,
          imageInfo: imgInfo,
        );
      } else if (dataList is Map<String, dynamic>) {
        return VerifyEtResult.fromJson(
          dataList,
          requestId: requestId,
          imageInfo: imgInfo,
        );
      } else if (body['verification'] is Map) {
        return VerifyEtResult.fromJson(
          body['verification'] as Map<String, dynamic>,
          requestId: requestId,
          imageInfo: imgInfo,
        );
      }
      return VerifyEtResult.fromJson(body, requestId: requestId, imageInfo: imgInfo);
    }

    if (res.statusCode == 202) {
      return _buildPendingResult(body);
    }

    // Error handling
    final errorMsg = body['message']?.toString() ??
        body['error']?['message']?.toString() ??
        body['error']?.toString() ??
        'HTTP ${res.statusCode} Error';

    final errorCode = body['error']?['code']?.toString();
    final lowerMsg = errorMsg.toLowerCase();

    if (res.statusCode == 401) {
      throw Exception('Invalid Verify.ET API Key (401). Please check your key in settings.');
    } else if (res.statusCode == 402) {
      throw Exception('Insufficient credits on Verify.ET account: $errorMsg');
    } else if (res.statusCode == 422) {
      if (lowerMsg.contains('suffix')) {
        throw Exception('Account suffix required: For older CBE FT references, please provide the 8-digit suffix (the last 8 digits of the receiver account number).');
      }
      throw Exception('Invalid bank fields or conflict: $errorMsg (${errorCode ?? ''})');
    } else if (res.statusCode == 429) {
      throw Exception('Rate limit exceeded or queue saturated. Please retry in 30 seconds.');
    } else {
      throw Exception(errorMsg);
    }
  }

  /// Fetches verification history from GET /api/verify/history.
  Future<List<VerifyEtHistoryItem>> fetchHistory({
    String? bank,
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    if (!hasApiKey) return [];

    final queryParams = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (bank != null && bank.isNotEmpty && bank != 'all') 'bank': bank,
      if (status != null && status.isNotEmpty && status != 'all') 'status': status,
    };

    final uri = Uri.parse('$defaultBaseUrl/api/verify/history').replace(queryParameters: queryParams);
    final res = await http.get(uri, headers: {
      'x-api-key': apiKey.value.trim(),
      'Accept': 'application/json',
    });

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'];
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((item) => VerifyEtHistoryItem.fromJson(item))
            .toList();
      }
    }
    return [];
  }
}
