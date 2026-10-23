import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

  final _service = Get.put(VerifyEtService(), permanent: true);

  // ── Form State ────────────────────────────────────────────────────────────
  final selectedBank = 'universal'.obs;
  final referenceCtrl = TextEditingController();
  final accountSuffixCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final settlementAccountCtrl = TextEditingController();

  // ── Settings State ────────────────────────────────────────────────────────
  final apiKeyCtrl = TextEditingController();
  final defaultSettlementCtrl = TextEditingController();

  // ── Image State ───────────────────────────────────────────────────────────
  final selectedImageBytes = Rxn<Uint8List>();
  final selectedImageName = RxnString();

  // ── Execution State ───────────────────────────────────────────────────────
  final isLoading = false.obs;
  final pollingStatusMessage = ''.obs;
  final activeResult = Rxn<VerifyEtResult>();
  final errorMessage = RxnString();

  // ── History State ─────────────────────────────────────────────────────────
  final historyList = <VerifyEtHistoryItem>[].obs;
  final isLoadingHistory = false.obs;

  @override
  void onInit() {
    super.onInit();
    apiKeyCtrl.text = _service.apiKey.value;
    defaultSettlementCtrl.text = _service.defaultSettlementAccount.value;

    if (_service.hasApiKey) {
      loadHistory();
    }
  }

  @override
  void onClose() {
    referenceCtrl.dispose();
    accountSuffixCtrl.dispose();
    phoneCtrl.dispose();
    settlementAccountCtrl.dispose();
    apiKeyCtrl.dispose();
    defaultSettlementCtrl.dispose();
    super.onClose();
  }

  bool get hasApiKey => _service.hasApiKey;

  void saveSettings() {
    _service.saveApiKey(apiKeyCtrl.text.trim());
    _service.saveDefaultSettlementAccount(defaultSettlementCtrl.text.trim());
    SnackbarHelper.success('Settings Saved', 'Verify.ET API Key and default settlement account updated.');
    if (historyList.isEmpty && _service.hasApiKey) {
      loadHistory();
    }
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
    settlementAccountCtrl.clear();
    clearImage();
    activeResult.value = null;
    errorMessage.value = null;
    pollingStatusMessage.value = '';
  }

  /// Pre-fills the verification form from a pending PaymentReview item.
  void prefillFromReview(PaymentReview review) {
    resetForm();

    // Guess bank from paymentMethod string
    final m = review.paymentMethod.toLowerCase();
    if (m.contains('telebirr')) {
      selectedBank.value = 'telebirr';
    } else if (m.contains('cbe') || m.contains('commercial_bank')) {
      selectedBank.value = 'cbe';
    } else if (m.contains('abyssinia') || m.contains('boa')) {
      selectedBank.value = 'boa';
    } else if (m.contains('mpesa') || m.contains('m-pesa')) {
      selectedBank.value = 'mpesa';
    } else if (m.contains('dashen')) {
      selectedBank.value = 'dashen';
    } else if (m.contains('awash')) {
      selectedBank.value = 'awash';
    } else {
      selectedBank.value = 'universal';
    }

    if (review.verificationUrl.isNotEmpty) {
      referenceCtrl.text = review.verificationUrl;
    }
  }

  /// Refreshes the verification status for a pending requestId
  Future<void> refreshStatus(String requestId) async {
    if (!_service.hasApiKey) return;
    isLoading.value = true;
    errorMessage.value = null;
    pollingStatusMessage.value = 'Checking verification status...';

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
      errorMessage.value = 'Please provide your Verify.ET API key first.';
      SnackbarHelper.warning('API Key Required', 'Please enter your Verify.ET API key in the settings section.');
      return;
    }

    final hasImage = selectedImageBytes.value != null;
    final ref = referenceCtrl.text.trim();

    if (!hasImage && ref.isEmpty) {
      errorMessage.value = 'Please enter a reference number or upload a receipt photo.';
      SnackbarHelper.warning('Missing Reference', 'Please enter a transaction ID, reference, or upload a receipt photo.');
      return;
    }

    isLoading.value = true;
    errorMessage.value = null;
    activeResult.value = null;
    pollingStatusMessage.value = '';

    try {
      VerifyEtResult res;

      void onTick(int attempt, int maxAttempts) {
        pollingStatusMessage.value = 'Checking bank confirmation ($attempt/$maxAttempts)...';
      }

      if (hasImage) {
        res = await _service.verifyReceiptImage(
          imageBytes: selectedImageBytes.value!,
          fileName: selectedImageName.value ?? 'receipt.jpg',
          bank: selectedBank.value,
          reference: ref.isNotEmpty ? ref : null,
          accountSuffix: accountSuffixCtrl.text.trim().isNotEmpty ? accountSuffixCtrl.text.trim() : null,
          phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
          settlementAccount: settlementAccountCtrl.text.trim().isNotEmpty ? settlementAccountCtrl.text.trim() : null,
          onPollTick: onTick,
        );
      } else {
        res = await _service.verifyTransaction(
          bank: selectedBank.value,
          reference: ref,
          accountSuffix: accountSuffixCtrl.text.trim().isNotEmpty ? accountSuffixCtrl.text.trim() : null,
          phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
          settlementAccount: settlementAccountCtrl.text.trim().isNotEmpty ? settlementAccountCtrl.text.trim() : null,
          onPollTick: onTick,
        );
      }

      activeResult.value = res;

      if (res.verified) {
        SnackbarHelper.success('Verified!', 'Transaction confirmed by ${res.bank.toUpperCase()}: ${res.amount} ${res.currency}');
      } else if (res.isPending) {
        SnackbarHelper.info(
          'Verification Queued',
          '${res.bank.toUpperCase()} verification is in progress. Use "Check Status" to refresh once processed.',
        );
      } else {
        SnackbarHelper.warning('Unverified', 'Status: ${res.status} (${res.processingStatus ?? 'unconfirmed'})');
      }

      // Reload verification history
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

  Future<void> loadHistory() async {
    if (!_service.hasApiKey) return;
    isLoadingHistory.value = true;
    try {
      historyList.value = await _service.fetchHistory();
    } catch (_) {
    } finally {
      isLoadingHistory.value = false;
    }
  }
}
