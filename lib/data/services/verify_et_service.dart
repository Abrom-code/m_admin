import 'dart:convert';
import 'dart:typed_data';

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

  /// Submits an instant bank receipt/transaction verification to Verify.ET.
  Future<VerifyEtResult> verifyTransaction({
    String? bank,
    required String reference,
    String? accountSuffix,
    String? phone,
    String? settlementAccount,
    int waitMs = 5000,
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
      if (accountSuffix != null && accountSuffix.trim().isNotEmpty) {
        payload['accountSuffix'] = accountSuffix.trim();
      }
      if (phone != null && phone.trim().isNotEmpty) {
        payload['phone'] = phone.trim();
      }
    } else {
      payload['bank'] = cleanBank;

      switch (cleanBank) {
        case 'cbe':
          payload['reference'] = trimmedRef;
          if (accountSuffix != null && accountSuffix.trim().isNotEmpty) {
            payload['accountSuffix'] = accountSuffix.trim();
          }
          break;

        case 'boa':
          payload['reference'] = trimmedRef;
          if (accountSuffix != null && accountSuffix.trim().isNotEmpty) {
            payload['accountSuffix'] = accountSuffix.trim();
          }
          break;

        case 'telebirr':
        case 'mpesa':
          payload['transactionNumber'] = trimmedRef;
          payload['reference'] = trimmedRef;
          break;

        case 'cbebirr':
          payload['receiptNumber'] = trimmedRef;
          payload['reference'] = trimmedRef;
          if (phone != null && phone.trim().isNotEmpty) {
            payload['phone'] = phone.trim();
          }
          break;

        case 'coopayebirr':
          payload['reference'] = trimmedRef;
          if (phone != null && phone.trim().isNotEmpty) {
            payload['phone'] = phone.trim();
          }
          break;

        case 'dashen':
        case 'awash':
        case 'siinqee':
        case 'kaafiebirr':
        default:
          payload['reference'] = trimmedRef;
          if (phone != null && phone.trim().isNotEmpty) {
            payload['phone'] = phone.trim();
          }
          break;
      }
    }

    final res = await http.post(
      uri,
      headers: _buildHeaders(idempotencyKey: 'v_${cleanBank ?? 'uni'}_${trimmedRef}_${DateTime.now().millisecondsSinceEpoch}'),
      body: jsonEncode(payload),
    );

    return _handleVerificationResponse(res);
  }

  /// Uploads a receipt image (JPEG, PNG, WebP) to Verify.ET for automated QR & OCR verification.
  Future<VerifyEtResult> verifyReceiptImage({
    required Uint8List imageBytes,
    required String fileName,
    String? bank,
    String? reference,
    String? accountSuffix,
    String? phone,
    String? settlementAccount,
    int waitMs = 5000,
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
    if (bank != null && bank.isNotEmpty && bank != 'universal') {
      req.fields['bank'] = bank.toLowerCase().trim();
    }
    if (reference != null && reference.trim().isNotEmpty) {
      req.fields['reference'] = reference.trim();
    }
    if (accountSuffix != null && accountSuffix.trim().isNotEmpty) {
      req.fields['accountSuffix'] = accountSuffix.trim();
    }
    if (phone != null && phone.trim().isNotEmpty) {
      req.fields['phone'] = phone.trim();
    }

    final streamedRes = await req.send();
    final res = await http.Response.fromStream(streamedRes);

    return _handleVerificationResponse(res);
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
      final reqId = body['requestId']?.toString();
      final status = body['verification']?['status']?.toString() ?? 'pending';
      return VerifyEtResult(
        bank: body['verification']?['bank']?.toString() ?? 'unknown',
        status: status,
        verified: false,
        amount: 0.0,
        currency: 'ETB',
        requestId: reqId,
        processingStatus: body['verification']?['processingStatus']?.toString() ?? 'queued',
        rawJson: body,
      );
    }

    // Error handling
    final errorMsg = body['message']?.toString() ??
        body['error']?['message']?.toString() ??
        body['error']?.toString() ??
        'HTTP ${res.statusCode} Error';

    final errorCode = body['error']?['code']?.toString();
    if (res.statusCode == 401) {
      throw Exception('Invalid Verify.ET API Key (401). Please check your key.');
    } else if (res.statusCode == 402) {
      throw Exception('Insufficient credits on Verify.ET account: $errorMsg');
    } else if (res.statusCode == 422) {
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
