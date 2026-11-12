import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/data/services/receipt_extractor_service.dart';
import 'package:m_admin/data/services/scanned_receipt_storage.dart';
import 'package:m_admin/data/services/verify_et_service.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/features/payments/models/verify_et_model.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class VerifyEtController extends GetxController {
  static VerifyEtController get instance =>
      Get.isRegistered<VerifyEtController>()
          ? Get.find<VerifyEtController>()
          : Get.put(VerifyEtController(), permanent: true);
  static bool get isRegistered => Get.isRegistered<VerifyEtController>();

  final _service = VerifyEtService.instance;
  final scannedStorage = ScannedReceiptStorage.instance;

  // ── Form State ────────────────────────────────────────────────────────────
  final selectedBank = 'universal'.obs;
  final referenceCtrl = TextEditingController();
  final accountSuffixCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  // ── Settings State ────────────────────────────────────────────────────────
  final apiKeyCtrl = TextEditingController();

  // ── Image State ───────────────────────────────────────────────────────────
  final selectedImageBytes = Rxn<Uint8List>();
  final selectedImageName = RxnString();

  // ── Execution State ───────────────────────────────────────────────────────
  final isLoading = false.obs;
  final pollingStatusMessage = ''.obs;
  final activeResult = Rxn<LinksEtResult>();
  final errorMessage = RxnString();

  // ── Double-Scan / Previous Verification Detection ─────────────────────────
  final previousScannedRecord = Rxn<ScannedReceiptRecord>();

  // ── Local Database History State ──────────────────────────────────────────
  final historyList = <VerifyEtHistoryItem>[].obs;
  final isLoadingHistory = false.obs;

  @override
  void onInit() {
    super.onInit();
    apiKeyCtrl.text = _service.apiKey.value;
    referenceCtrl.addListener(_onInputChanged);
    loadHistory();
  }

  @override
  void onClose() {
    referenceCtrl.removeListener(_onInputChanged);
    referenceCtrl.dispose();
    accountSuffixCtrl.dispose();
    phoneCtrl.dispose();
    apiKeyCtrl.dispose();
    super.onClose();
  }

  void checkPriorScan() => _onInputChanged();

  void _onInputChanged() {
    final text = referenceCtrl.text.trim();
    if (text.isEmpty) {
      previousScannedRecord.value = null;
      return;
    }
    final existing = scannedStorage.findRecord(text);
    previousScannedRecord.value = existing;

    if ((selectedBank.value == 'cbe' || selectedBank.value == 'boa' || text.toUpperCase().startsWith('FT')) &&
        !text.startsWith('http') &&
        text != text.toUpperCase()) {
      final clean = text.toUpperCase();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (referenceCtrl.text != clean) {
          referenceCtrl.value = TextEditingValue(
            text: clean,
            selection: TextSelection.collapsed(offset: clean.length),
          );
        }
      });
    }
  }

  bool get hasApiKey => _service.hasApiKey;

  void saveSettings() {
    _service.saveApiKey(apiKeyCtrl.text.trim());
    SnackbarHelper.success('Settings Saved', 'Verify.ET API Key updated successfully.');
    loadHistory();
  }

  Future<void> pickReceiptImage() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        selectedImageBytes.value = bytes;
        selectedImageName.value = file.name;

        // Perform fast on-device OCR extraction immediately so the user doesn't hit
        // the "Image Processing is disabled on your Verify.ET account" wall!
        try {
          final res = await ReceiptExtractorService.instance.extractFromBytes(
            bytes,
            bankHint: selectedBank.value,
            fileName: file.name,
          );

          if (res != null && res.hasTransactionId) {
            final targetRef = res.receiptUrl ?? res.transactionId!;
            referenceCtrl.text = targetRef;
            if (res.bank != null && res.bank!.isNotEmpty) {
              selectBank(res.bank!);
            }
            if (res.receiverAccount != null && res.receiverAccount!.isNotEmpty) {
              final bank = selectedBank.value;
              accountSuffixCtrl.text = VerifyEtService.sanitizeAccountSuffix(res.receiverAccount!, bank);
            }
            _onInputChanged();
            SnackbarHelper.success(
              'Extracted from Image',
              'Found ${res.bank?.toUpperCase() ?? 'Bank'} reference: $targetRef',
            );
          }
        } catch (ocrErr) {
          debugPrint('[VerifyEtController] On-device OCR notice: $ocrErr');
        }
      }
    } catch (e) {
      SnackbarHelper.error('File Error', 'Could not select receipt image: $e');
    }
  }

  void clearImage() {
    selectedImageBytes.value = null;
    selectedImageName.value = null;
  }

  void resetForm() {
    referenceCtrl.clear();
    accountSuffixCtrl.clear();
    phoneCtrl.clear();
    clearImage();
    activeResult.value = null;
    errorMessage.value = null;
    pollingStatusMessage.value = '';
    previousScannedRecord.value = null;
  }

  void selectBank(String bankId) {
    selectedBank.value = bankId;
    if (accountSuffixCtrl.text.isEmpty) {
      if (bankId == 'boa') {
        accountSuffixCtrl.text = VerifyEtService.resolveDefaultAccountSuffix('boa');
      } else if (bankId == 'cbe') {
        accountSuffixCtrl.text = VerifyEtService.resolveDefaultAccountSuffix('cbe');
      }
    }
  }

  /// Pre-fills the verification form from a pending PaymentReview item.
  void prefillFromReview(PaymentReview review) {
    resetForm();

    // Determine bank from paymentMethod string
    final m = review.paymentMethod.toLowerCase();
    if (m.contains('telebirr')) {
      selectedBank.value = 'telebirr';
    } else if (m.contains('cbe') || m.contains('commercial_bank')) {
      selectedBank.value = 'cbe';
    } else if (m.contains('abyssinia') || m.contains('boa')) {
      selectedBank.value = 'boa';
    } else if (m.contains('awash')) {
      selectedBank.value = 'awash';
    } else if (m.contains('zemen')) {
      selectedBank.value = 'zemen';
    } else if (m.contains('dashen')) {
      selectedBank.value = 'dashen';
    } else if (m.contains('cbebirr') || m.contains('cbe_birr')) {
      selectedBank.value = 'cbebirr';
    } else if (m.contains('mpesa') || m.contains('m-pesa')) {
      selectedBank.value = 'mpesa';
    } else if (m.contains('oromia') || m.contains('coop') || m.contains('coopay')) {
      selectedBank.value = 'oromia';
    } else {
      selectedBank.value = 'universal';
    }

    // Auto-prefill account suffix if BOA or CBE
    if (selectedBank.value == 'boa') {
      accountSuffixCtrl.text = VerifyEtService.resolveDefaultAccountSuffix('boa');
    } else if (selectedBank.value == 'cbe') {
      accountSuffixCtrl.text = VerifyEtService.resolveDefaultAccountSuffix('cbe');
    }

    if (review.verificationUrl.isNotEmpty) {
      final raw = review.verificationUrl.trim();
      if (selectedBank.value == 'telebirr') {
        final cleanTok = VerifyEtService.sanitizeTelebirrReference(raw);
        referenceCtrl.text = cleanTok.isNotEmpty && !cleanTok.startsWith('http') ? cleanTok : raw;
      } else if (!raw.startsWith('http') &&
          (selectedBank.value == 'cbe' || selectedBank.value == 'boa' || raw.toUpperCase().startsWith('FT'))) {
        referenceCtrl.text = raw.toUpperCase();
      } else {
        referenceCtrl.text = raw;
      }
    }
  }

  /// Refreshes the verification status for a queued requestId
  Future<void> refreshStatus(String requestId) async {
    if (!_service.hasApiKey) return;
    isLoading.value = true;
    errorMessage.value = null;
    pollingStatusMessage.value = 'Checking verification status on verify.et...';

    try {
      final res = await _service.getVerificationStatus(requestId);
      activeResult.value = res;

      if (res.verified) {
        SnackbarHelper.success(
          'Verified!',
          'Transaction confirmed by ${res.bank.toUpperCase()}: ${res.amount} ${res.currency}',
        );
      } else if (res.isPending) {
        SnackbarHelper.info(
          'Still Queued',
          'Verification is still in progress on ${res.bank.toUpperCase()} network. Please try again shortly.',
        );
      } else {
        SnackbarHelper.warning('Unverified', 'Status: ${res.status}');
      }
      loadHistory();
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      errorMessage.value = msg;
      SnackbarHelper.error('Status Check Error', msg);
    } finally {
      isLoading.value = false;
      pollingStatusMessage.value = '';
    }
  }

  /// Triggers verification via Verify.ET
  Future<void> submitVerification() async {
    if (!_service.hasApiKey) {
      errorMessage.value = 'Please configure your Verify.ET API key (VERIFY_BANK_ET_...) first.';
      SnackbarHelper.warning('API Key Required', 'Please enter your Verify.ET API key in settings.');
      return;
    }

    final hasImage = selectedImageBytes.value != null;
    final inputVal = referenceCtrl.text.trim();
    final bank = selectedBank.value;

    if (!hasImage && inputVal.isEmpty) {
      errorMessage.value = 'Please enter a receipt URL or Telebirr reference.';
      SnackbarHelper.warning('Input Required', 'Please provide a receipt link or reference number.');
      return;
    }

    ResolvedReceiptInput? resolved;
    if (!hasImage) {
      resolved = LinksEtService.resolveReceiptInput(
        input: inputVal,
        bank: bank,
      );
      if (resolved.primaryTarget.isEmpty) {
        errorMessage.value = 'Please enter a valid reference, receipt URL, or confirmation SMS.';
        SnackbarHelper.warning('Input Required', 'Please provide a receipt link or reference number.');
        return;
      }
    }

    isLoading.value = true;
    errorMessage.value = null;
    activeResult.value = null;
    pollingStatusMessage.value = resolved?.isAutoConstructed == true && resolved?.note != null
        ? resolved!.note!
        : '';

    // Check for prior scan in local database
    final existing = scannedStorage.findRecord(inputVal);
    previousScannedRecord.value = existing;

    try {
      LinksEtResult res;

      void onTick(int attempt, int maxAttempts) {
        pollingStatusMessage.value = 'Checking upstream bank confirmation ($attempt/$maxAttempts)...';
      }

      if (hasImage && inputVal.isEmpty) {
        res = await _service.verifyScreenshot(
          imageBytes: selectedImageBytes.value!,
          fileName: selectedImageName.value,
          bankHint: bank,
          accountSuffix: accountSuffixCtrl.text.trim().isNotEmpty
              ? accountSuffixCtrl.text.trim()
              : null,
          phone: phoneCtrl.text.trim().isNotEmpty
              ? phoneCtrl.text.trim()
              : null,
          onPollTick: onTick,
        );
      } else {
        final r = resolved ??
            LinksEtService.resolveReceiptInput(
              input: inputVal,
              bank: bank,
            );
        final rawSuffix = accountSuffixCtrl.text.trim().isNotEmpty
            ? accountSuffixCtrl.text.trim()
            : r.accountSuffix;
        final effSuffix = (rawSuffix != null && rawSuffix.isNotEmpty)
            ? VerifyEtService.sanitizeAccountSuffix(rawSuffix, r.resolvedBank)
            : null;
        final effPhone = phoneCtrl.text.trim().isNotEmpty
            ? phoneCtrl.text.trim()
            : r.phone;

        res = await _service.verifyReceipt(
          url: r.url,
          reference: r.reference,
          bankHint: r.resolvedBank,
          accountSuffix: effSuffix,
          phone: effPhone,
          settlementAccount: VerifyEtService.resolveDefaultSettlementAccount(r.resolvedBank),
          onPollTick: onTick,
        );
      }

      activeResult.value = res;

      if (res.verified) {
        final amountStr = '${res.amount} ${res.currency}';
        final bankLabel = res.bank.toUpperCase();
        if (existing != null) {
          SnackbarHelper.warning(
            'Already Scanned Before!',
            'Verified $bankLabel receipt ($amountStr). Note: This receipt was previously scanned on ${existing.formattedScannedDate} (Status: ${existing.status}).',
          );
        } else {
          SnackbarHelper.success('Verified at Source!', 'Confirmed by $bankLabel: $amountStr');
        }
      } else if (res.isPending) {
        SnackbarHelper.info(
          'Verification Queued',
          '${res.bank.toUpperCase()} verification is in progress upstream. Use "Check Status" to refresh.',
        );
      } else {
        final reason = res.userFriendlyErrorMessage;
        SnackbarHelper.warning('Not Verified', reason);
      }

      // Reload local database history
      loadHistory();
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      errorMessage.value = msg;
      SnackbarHelper.error('Verification Error', msg);
    } finally {
      isLoading.value = false;
      pollingStatusMessage.value = '';
    }
  }

  /// Loads verified/scanned receipt history from the local database.
  Future<void> loadHistory() async {
    isLoadingHistory.value = true;
    try {
      historyList.value = await _service.fetchHistory();
    } catch (_) {
    } finally {
      isLoadingHistory.value = false;
    }
  }

  /// Removes a history item from the local app database.
  void deleteHistoryRecord(String id) {
    scannedStorage.removeRecord(id);
    loadHistory();
  }

  /// Clears all stored verification records from local database.
  void clearAllHistory() {
    scannedStorage.clearAll();
    loadHistory();
    previousScannedRecord.value = null;
    SnackbarHelper.info('Database Cleared', 'All local scanned receipt records have been removed.');
  }
}
