# MatricMate Student App — Complete Optimization & Cloudflare R2 Roadmap

This roadmap contains the complete, step-by-step instructions to update the **MatricMate Student App** (`matricmate`). It finalizes the migration to **Cloudflare R2**, prevents Supabase quota overages, and optimizes battery, network, and memory usage.

---

## 0. Current Infrastructure State

* **Supabase Storage Buckets:** Both `questions` and `receipts` buckets have been removed from Supabase.
* **Question Diagrams & Images:** Hosted on public Cloudflare R2 at:
  `https://pub-43a16bf04c744fdf95b3cef14f5ca1c1.r2.dev/`
* **Receipts & Note PDFs:** Hosted on private Cloudflare R2 in bucket `matricet-notes` (receipts under prefix `receipts/`).
* **Supabase Edge Function:** `receipt-storage` is deployed and handles:
  - `get_upload_url` $\rightarrow$ Generates 5-minute presigned S3 PUT URL for direct client upload.
  - `get_view_url` $\rightarrow$ Generates 15-minute presigned S3 GET URL for admin audit.

---

## Task 1: Auto-Compress Receipt Photos & Upload Directly to Cloudflare R2

### 1.1 Auto-Compress Receipt Photos on Pick
* 📂 **File:** `lib/features/exam/controllers/premium_controller.dart`
* 📍 **Method:** `pickReceipt()` (around line 117)
* **Goal:** Auto-scale and compress raw 5–8 MB camera photos down to ~150 KB.

#### Replace `pickReceipt()` with:
```dart
  Future<void> pickReceipt() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1800,
        imageQuality: 80,
      );
      if (file != null) {
        receipt.value = file;
        showReceiptError.value = false;
      }
    } catch (_) {
      ToastHelper.error('Failed to pick image');
    }
  }
```

---

### 1.2 Direct Cloudflare R2 Upload & Dead Bucket Cleanup
* 📂 **File:** `lib/data/repositories/payment/payment_repository.dart`
* 📍 **Imports:** Ensure `import 'package:http/http.dart' as http;` is present.
* 📍 **Method 1:** Replace `uploadReceipt()` (around line 53)
* 📍 **Method 2:** Clean up `deleteUserReceipts()` (around line 120)

#### Replace `uploadReceipt()` with:
```dart
  /// Uploads receipt directly to Cloudflare R2 via presigned PUT URL (0 MB on Supabase Storage).
  Future<Map<String, String>> uploadReceipt(XFile file, String userId) async {
    try {
      final bytes = await file.readAsBytes();
      final fileName = 'receipt_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 1. Request temporary presigned Cloudflare R2 upload URL from Edge Function
      final edgeRes = await _supabase.functions.invoke(
        'receipt-storage',
        body: {
          'action': 'get_upload_url',
          'file_name': fileName,
        },
      ).timeout(AppTimeouts.upload);

      final data = edgeRes.data as Map<String, dynamic>;
      final uploadUrl = data['upload_url'] as String;
      final fileKey = data['file_key'] as String;

      // 2. Upload binary directly to Cloudflare R2 via HTTP PUT
      final httpResponse = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Content-Type': 'image/jpeg',
        },
        body: bytes,
      ).timeout(AppTimeouts.upload);

      if (httpResponse.statusCode != 200) {
        throw 'Failed to upload receipt to Cloudflare (HTTP ${httpResponse.statusCode})';
      }

      return {
        'filePath': fileKey,
        'url': fileKey,
      };
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[PaymentRepository] uploadReceipt error: $e\n$st');
      }
      throw AppExceptionHandler.handle(e);
    }
  }
```

#### In `deleteUserReceipts()` (lines 126–138):
Remove the dead call to `_supabase.storage.from('receipts').remove(...)`:
```dart
      // 1. Delete every receipt row for this user from database table
      await _supabase.from('payment_receipts').delete().eq('user_id', userId).timeout(AppTimeouts.delete);

      // 2. Revert to inactive and reset upload count only when status is still pending
      await _supabase
          .from('users')
          .update({
            'subscription_status': 'inactive',
            'receipt_upload_count': 0,
          })
          .eq('id', userId)
          .eq('subscription_status', 'pending')
          .timeout(AppTimeouts.delete);
```

---

### 1.3 Remove Dead Storage Call in User Repository
* 📂 **File:** `lib/data/repositories/user/user_repository.dart`
* 📍 **Method:** `deleteUserRecord()` (around line 72)
* **Goal:** Remove dead reference to deleted Supabase `receipts` bucket.

#### In `deleteUserRecord()`, remove the storage block:
```dart
  Future<void> deleteUserRecord(String userId) async {
    try {
      // Clear local user table
      final db = await databaseService.database;
      await db.delete('user');
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }
```

---

## Task 2: Fix Challenge Exam Performance & Kill Traffic Storms

### 2.1 Eliminate 50+ Individual Network Calls per Challenge Attempt
* 📂 **File:** `lib/features/challenges/controllers/challenge_attempt_controller.dart`
* 📍 **Method:** `selectChoice()` (around line 277)
* **Problem:** Every radio button tap was sending an immediate HTTP RPC request (`rpc_submit_answer`) to Supabase.
* **Fix:** Store choice in memory and SQLite immediately for 100% offline safety; all answers are synced in a single batch when submitting.

#### Replace `selectChoice()` with:
```dart
  void selectChoice(String questionId, String choice) {
    if (userAnswers[questionId] == choice) return;

    userAnswers[questionId] = choice;
    _saveLastQuestionIndex(currentIndex.value);

    // Save locally to SQLite immediately — zero network latency, 100% crash/offline safe
    DatabaseService.instance.saveChallengePracticeResult(
      challengeId: challengeId,
      score: 0,
      totalQuestions: totalQuestions,
      userAnswers: Map<String, String>.from(userAnswers),
      timeSpentSeconds: _timeSpentSeconds,
    ).catchError((_) {});
  }
```

---

### 2.2 Kill Challenge Realtime Cascade & Add Missing `onClose()`
* 📂 **File:** `lib/features/challenges/controllers/challenge_home_controller.dart`
* 📍 **Location:** Lines 190–226 (`_startRealtime()`) and add `onClose()`
* **Problem:** Listening to `challenge_attempts` triggers a broadcast storm to all active students whenever any user in the country finishes a test. Also, channels were never closed on screen exit.

#### Replace `_startRealtime()` and add `onClose()`:
```dart
  void _startRealtime() {
    if (_realtimeChannel != null) {
      _sb.removeChannel(_realtimeChannel!);
    }
    // Only listen to leaderboard_challenges status transitions (live/closed)
    _realtimeChannel = _sb
        .channel('public:leaderboard_challenges')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'leaderboard_challenges',
          callback: (payload) {
            debugPrint('[Realtime] Challenge changed: ${payload.eventType}');
            loadAllChallenges(showLoading: false);
          },
        )
        .subscribe((status, [error]) {
          debugPrint('[Realtime] Challenges status: $status ${error ?? ''}');
        });
  }

  @override
  void onClose() {
    _countdownTimer?.cancel();
    if (_realtimeChannel != null) {
      _sb.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
    super.onClose();
  }
```

---

## Task 3: Prevent Re-Downloading Existing Question Images

* 📂 **File:** `lib/utils/helpers/helper_functions.dart`
* 📍 **Method:** `AppHelperFunctions.downloadImages()` (around line 41)
* **Problem:** `cache.downloadFile(url)` forces a fresh download over the network even if the image is already cached on the phone.
* **Fix:** Check `cache.getFileFromCache(url)` first.

#### In `downloadImages()`, update the `worker()` loop:
```dart
    Future<void> worker() async {
      while (true) {
        if (index >= validUrls.length) break;
        final url = validUrls[index++];
        try {
          // Check if image is already cached on device
          final existing = await cache.getFileFromCache(url);
          if (existing == null || !existing.file.existsSync() || existing.file.lengthSync() == 0) {
            await cache.downloadFile(url).timeout(const Duration(seconds: 12));
          }
        } catch (e) {
          debugPrint('Image download failed for $url: $e');
        } finally {
          completed++;
          onProgress?.call(completed / validUrls.length);
        }
      }
    }
```

---

## Task 4: Prune Redundant Questions Realtime Channel

* 📂 **File:** `lib/data/services/realtime_service.dart`
* 📍 **Method:** `start()` (around line 30)
* **Problem:** An unfiltered live WebSocket channel on the entire `questions` table maintains continuous pings and broadcasts. Exam questions are already updated via delta sync on app launch.

#### Update `start()`:
```dart
  Future<void> start(List<int> subjectIds, {required String userId}) async {
    await stop();
    // Questions are kept in sync via delta sync during app launch / pull-to-refresh.
    // Disabling the live unfiltered questions channel saves continuous ping logs and bandwidth.
    // _startQuestionChannel(subjectIds);
    _startUserChannel(userId);
    _startAppConfigChannel();
    _startNotificationsChannel(userId);
    _startNotificationReadsChannel(userId);
  }
```

---

## 5. Verification & Testing Checklist

After applying the edits above in `matricmate`:

- [ ] **Test Question Images:** Open any subject (e.g., Biology or Physics) that contains diagrams. Verify images load cleanly and quickly from `pub-43a16bf04c744fdf95b3cef14f5ca1c1.r2.dev`.
- [ ] **Test Offline Mode:** Switch phone to Airplane mode. Open previously downloaded subject questions and verify diagrams load instantly from local cache.
- [ ] **Test Receipt Upload:** In the upgrade screen, pick a payment receipt photo. Verify:
  1. The selected photo is compressed smoothly without lag.
  2. The upload completes via `receipt-storage` into Cloudflare R2 (`matricet-notes/receipts/`).
  3. In the Admin app, open the payment review screen and verify the receipt displays clearly.
- [ ] **Test Challenge Exam:** Start a challenge test. Tap choices A, B, C, D across several questions. Verify transitions are instant with zero network lag, and submitting properly scores and records the attempt.
- [ ] **Run Code Quality Check:**
  ```bash
  flutter analyze
  ```
