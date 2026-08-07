# MatricMate Admin — Build Prompt

A step-by-step prompt pack for generating the MatricMate admin app. Feed **Phase 0** first (it is context, not work), then paste one phase at a time and verify its acceptance criteria before moving on.

Every table name, column name, colour, and constant below was read out of the real `matricmate` codebase. Facts marked ⚠️ **INFERRED** were reconstructed from Dart call sites because the repo contains **no SQL migrations** — verify them in the Supabase dashboard before generating code against them.

---

# PHASE 0 — Context (paste this before every phase, or keep it in `CLAUDE.md`)

## 0.1 What exists today

MatricMate is a Flutter exam-prep app for Ethiopian matric students. 213 Dart files, ~23,600 lines, offline-first.

**Stack**
| Concern | Choice |
|---|---|
| Dart SDK | `^3.10.0` |
| State / DI / routing | **GetX** `^4.7.3` (`GetMaterialApp`, `Bindings`, `Obx`, `Get.toNamed`) |
| Auth (identity) | **Firebase Auth** `^6.3.0` — email/password. The user id everywhere is the **Firebase UID string** |
| Backend data | **Supabase** `supabase_flutter ^2.12.2` (Postgres + Storage + Realtime + Edge Functions) |
| Local cache | **sqflite** `^2.4.2` |
| Push | `firebase_messaging ^16.4.3` + `flutter_local_notifications ^22.2.0` |
| Icons | `iconsax_flutter ^1.0.1` + Material icons |
| Fonts | `google_fonts ^6.2.1` — **Inter** for UI, **Lora** for long-form question/passage text |
| Charts | **none — all hand-rolled `CustomPainter`** |
| Toast/snackbar | `fluttertoast ^9.0.0` + a custom `ToastHost` overlay |

**Critical auth quirk.** Supabase is authenticated **anonymously**. `lib/data/services/ensure_supabase_auth.dart`:

```dart
Future<void> ensureSupabaseAuth() async {
  final client = Supabase.instance.client;
  if (client.auth.currentSession != null) return;
  try {
    await client.auth.signInAnonymously();
  } catch (e) {
    throw AppExceptionHandler.handle(e);
  }
}
```

So `auth.uid()` is a throwaway anon UUID with **no relationship** to the `users.id` (Firebase UID) that rows are keyed by. RLS therefore cannot express "only your own row" today, and **there is no admin role concept anywhere in the codebase**. Phase 1 and Phase 4 fix this for the admin app.

## 0.2 Supabase schema — verified usage

Nine tables plus one storage bucket are touched by the client. ⚠️ Column lists are **INFERRED from call sites**; there are no migrations in `supabase/` (only `functions/send-push/index.ts` and `functions/deno.json`).

### `users`
| Column | Type | Notes |
|---|---|---|
| `id` | `text` PK | **Firebase UID**, not a Supabase auth uuid |
| `first_name` | `text` | |
| `last_name` | `text` | |
| `email` | `text` | |
| `stream` | `text` | `'natural'` \| `'social'` \| `'common'`; defaults `'natural'` at signup |
| `subscription_status` | `text` | `'inactive'` \| `'pending'` \| `'active'` — **this is the entire premium flag** |
| `fcm_token` | `text` | written by raw update, **not part of `UserModel`** |
| `created_at` | `timestamptz` | ⚠️ never read or written by the app — existence unverified |

`UserModel` maps `subscription_status` → Dart field `status`. There is **no `is_premium`, no expiry date, no plan type, and no plan duration**. Activation is permanent until someone changes the string back.

### `payment_receipts`
| Column | Type | Written by |
|---|---|---|
| `user_id` | `text` | Firebase UID |
| `receipt_path` | `text` | storage object name — the only column ever `select`ed |
| `receipt_url` | `text` | public URL |
| `payment_method` | `text` | `'telebirr'` \| `'cbe'` \| `'abyssinia'` \| `'mpesa'` (lowercase enum `.name`) |
| `verification_url` | `text` | user-pasted transaction link |

**No `status`, no `amount`, no `reviewed_by`, no `reviewed_at`, no `rejection_reason`.** `id` and `created_at` are never referenced in Dart.

### `notifications`
| Column | Type | Notes |
|---|---|---|
| `id` | `bigint` PK | Supabase returns this as a **String** in Dart |
| `user_id` | `uuid` **NULL** | `NULL` = broadcast row |
| `title`, `body` | `text` | |
| `type` | `text` | `'announcement'` \| `'payment'` \| `'new_content'` |
| `target_stream` | `text` NULL | `NULL` = global; `'natural'` / `'social'` = stream-scoped. **Exists remotely only** — not in the Dart model, not in local SQLite |
| `payload` | `jsonb` | |
| `is_read` | `boolean` | |
| `created_at` | `timestamptz` | |

### `user_sessions` — single-device lock (unrelated to FCM)
`firebase_uid`, `device_id` (a `uuid.v4()` in `SharedPreferences`), `trial` (`int`, seeded to `5`).

### Content tables
```
subjects   (id, name UNIQUE, is_natural bool, is_common bool)
chapters   (id, subject_id → subjects, grade, chapter_number, title)
tests      (id, subject_id, grade, chapter_id, title, type, question_count,
            time DEFAULT -1, created_at, updated_at)
            -- type ∈ 'chapter' | 'grade' | 'entrance' | 'model';  time = -1 means untimed
questions  (id, subject_id, grade, chapter_id, test_id, passage_id,
            question_text, image_url, options /* json array */, correct_option_index,
            explanation_en, explanation_am, explanation_image_url,
            question_order, section_id, updated_at)
passages   (id, content, title, image_url, updated_at)
question_sections (id, title)   -- joined via questions.section_id
```
Sync relies on `updated_at` on `tests`, `questions`, `passages`. **`chapters` and `subjects` have no `updated_at`** — they full-sync every time.

### Storage
Bucket **`receipts`** — public (`getPublicUrl`, no signed URLs). Flat paths, always `.jpg` regardless of real type:
```
receipt_{firebaseUid}_{epochMillis}.jpg
```

## 0.3 The push pipeline

Edge function `supabase/functions/send-push/index.ts`. Mints a service-account JWT (RS256) → `oauth2.googleapis.com/token` (scope `firebase.messaging`) → `POST https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`.

Secrets: `FCM_SERVICE_ACCOUNT_JSON`, `FCM_PROJECT_ID`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.

Helpers: `sendFcmToTopic(topic, notification, data)`, `sendFcmToToken(token, notification, data)`.

**It accepts exactly two events; everything else 400s:**
```ts
switch (body.event) {
  case "new_test":       await handleNewTest(...); break;
  case "payment_status": await handlePaymentStatus(...); break;
  default: return new Response(JSON.stringify({error: "unknown event"}), {status: 400});
}
```
- `new_test` → inserts a broadcast row (`user_id: null`, `type: 'new_content'`) and topic-sends.
- `payment_status` `{event, user_id, status}` → inserts a personal row (`type: 'payment'`, `payload: {status}`) and token-sends. Copy: `active` → *"Payment Approved! 🎉"*, `pending` → *"Payment Pending"*, `rejected` → *"Payment Rejected"*, else *"Payment Update"*.

**FCM topics the client subscribes to:** `all_users`, and exactly one of `stream_natural` / `stream_social`. Android channel id `matricmate_default`.

**Every FCM `data` value must be a String.** Deep-link keys consumed by `NotificationTestOpener.open(data)` — it prefers `test_type` over `type`:

| `test_type` | Destination | Required keys |
|---|---|---|
| `chapter` | `ChapterTestScreen` | `subject`, `subject_id`, `grade`, `chapter`, `chapter_id`, `chapter_number` |
| `grade` | `GradeTestsScreen` | `subject`, `subject_id`, `grade` |
| `entrance` | `EntranceExamsScreen` tab 0 | `subject`, `subject_id` |
| `model` | `EntranceExamsScreen` tab 1 | `subject`, `subject_id` |

Realtime prerequisites already documented in `realtime_service.dart`:
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
ALTER TABLE public.users REPLICA IDENTITY FULL;
```
The client watches `questions` (UPDATE, unfiltered) and `users` (UPDATE, `eq id`). **It does not watch `notifications`** — a row inserted without an accompanying push won't surface until the user opens the notifications screen.

## 0.4 Six blockers you must know before writing a line of admin code

These are real gaps in the current backend. Phases 1–2 close them; do not skip those phases.

1. **All learning data is device-local.** `results` and `bookmarks` exist **only** in per-device SQLite and are never uploaded. "Tests taken", "average score", "per-subject performance" are **not computable app-wide today**. An admin dashboard querying a Supabase `results` table would compile and return nothing.
2. **No revenue data.** `payment_receipts` has no `amount` column. The price (`250 ETB`) is a hardcoded string in `premium.dart:56` — never stored, never validated, never sent to the backend.
3. **No payment review state.** Approving is a bare `UPDATE users SET subscription_status='active'`. Nothing records who approved it, when, or why it was rejected. There is no audit trail and no queue state.
4. **`'rejected'` breaks the client.** The edge function has copy for it, but `UserModel`'s `isActive`/`isPending`/`isInactive` getters **all return false** for `'rejected'` — the user gets a push and lands in a UI dead zone. Either add `'rejected'` to the model or have the admin write `'inactive'` plus a reason.
5. **Broadcast read state is global.** `is_read` is one scalar on a shared `user_id IS NULL` row. The first user to tap a broadcast marks it read **for everyone**. `markAllRead` also silently reverts on next sync because its `.eq('user_id', userId)` doesn't match broadcast rows.
6. **`send-push` is unauthenticated.** `Deno.serve` acts on any POST, and Supabase's default `verify_jwt` is satisfied by the anon key that ships inside the APK. Anyone can forge `{"event":"payment_status","user_id":"<any>","status":"active"}`. Also: no `announcement` event exists yet.

Additional smaller notes: `fcm_service.dart:83` still logs the raw FCM token with a `TODO: Remove before production`; one token per user means multi-device users lose push on the older device; notification sync is capped at `.limit(100)` with no delete/expiry path.

## 0.5 Design system — copy these values exactly

**Colours** (`lib/utils/constants/colors.dart`)
```dart
primary = Colors.teal;            secondary = Colors.blueAccent;
accent  = Color(0xFFb0c7ff);      amberAccent = Color(0xFFE9A94A);
textPrimary = Color(0xFF1C1C1E);  textSecondary = Color(0xFF6C757D);
light = Color(0xFFF2F3F5);        dark = Color(0xFF0F0F0F);        // scaffolds
lightContainer = Color(0xFFFFFFFF);  lightCard = Color(0xFFEDF0ED);
darkCard = Color(0xFF1E1E1E);     darkSurface = Color(0xFF272727);
darkChoice = Color.fromARGB(255,22,22,22);
borderPrimary = Color(0xFFDDE1E7); darkBorder = Color(0xFF2E2E2E);
error = Color(0xFFd32f2f);  success = Color(0xFF388e3c);
warning = Color(0xFFf57c00); info = Color(0xFF1976d2);
black = Color(0xFF0A0A0A);  darkerGrey = Color(0xFF1C1C1E);
darkGrey = Color(0xFF939393); grey = Color(0xFFE0E0E0);
softGrey = Color(0xFFF4F4F4); lightGrey = Color(0xFFF9F9F9); white = Color(0xFFFFFFFF);
```

**Sizes** (`lib/utils/constants/sizes.dart`)
```dart
xs 4  sm 8  md 16  lg 24  xl 32
iconXs 12  iconSm 16  iconMd 24  iconLg 32
fonAppSizeSm 14  fontSizeMd 16  fontSizeLg 18   // note the typo — keep it
buttonHeight 18  buttonRadius 12  buttonWidth 120  appBarHeight 56
defaultSpace 24  spaceBtwItems 16  spaceBtwSections 32
borderRadiusSm 4  borderRadiusMd 8  borderRadiusLg 12
spaceBtwInputFields 16  gridViewSpacing 16
```

**Themes** — `useMaterial3: true`, `ColorScheme.fromSeed(seedColor: Colors.teal)`, `GoogleFonts.interTextTheme(...)`, `cardTheme` elevation `0` with radius `16`, floating snackbars with radius `12`.

**The card idiom — repeated verbatim in every analytics section. Reuse it.**
```dart
Container(
  padding: const EdgeInsets.all(AppSizes.md),
  decoration: BoxDecoration(
    color: dark ? AppColors.darkCard : AppColors.white,
    borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
    boxShadow: [BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 10, spreadRadius: -2, offset: const Offset(0, 4),
    )],
  ),
```
Dark mode is read **per widget** via `AppHelperFunctions.isDark(context)` — not from a global. Use `.withValues(alpha: x)`, never the deprecated `.withOpacity`.

**Charts, hand-rolled — match these specs**
- Line: 130px tall, `range = (max-min).clamp(1.0, 100.0)`, midpoint cubic smoothing `cubicTo((prev.dx+o.dx)/2, prev.dy, (prev.dx+o.dx)/2, o.dy, o.dx, o.dy)`, `strokeWidth 2.5`, `StrokeCap.round`, gradient fill `primary` alpha `0.2 → 0.0`, last point = two circles (r5 primary + r3 white), bails on `points.length < 2`.
- Donut: `drawArc`, `strokeWidth 18`, `radius = size.width/2 - 8`, start `-math.pi/2`, `gap = 0.03` rad, laid out 110×110 beside a legend of 10px dots.
- Bars: plain `LinearProgressIndicator` (`minHeight: 7`) in `ClipRRect(borderRadius: 4)`.
- Threshold ramp used everywhere: `>= 70 success, >= 50 warning, else error`.
- Test-type colours: `chapter→primary, entrance→info, model→success, grade→warning`.
- Empty state: centred `Text('No data yet')` in `textSecondary`.

## 0.6 Code conventions — match these exactly

**Repository**
```dart
class XRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<T> doThing(...) async {
    try {
      await ensureSupabaseAuth();          // admin app replaces this with a real session
      ...
    } catch (e) {
      throw AppExceptionHandler.handle(e); // returns AppFailure{title, message, code}
    }
  }
}
```

**Errors** — `AppExceptionHandler.handle(e)` → `AppFailure`. `AppExceptionHandler.handleResponse(e)` surfaces it via `SnackbarHelper.error(title, message)`. It already special-cases `FirebaseAuthException`, `PostgrestException`, `AuthException`, `StorageException`, `SocketException`, `TimeoutException`, sqflite, `FormatException`, `PlatformException`.

**Routing** — a `Routes` class of `static const` path strings, and `AppRoutes.pages` as a `List<GetPage>` with a `binding:` per page.

**DI** — a `GeneralBinding extends Bindings` registering core singletons with `Get.put(..., permanent: true)`; per-route controllers via `Get.lazyPut(..., fenix: true)` in their own binding file.

**Reactivity** — `.obs` fields on `GetxController`, `Obx(() => ...)` in the view, `Get.find<X>()` / `X.instance`, and `ever(...)` workers for cross-controller reactions. Guard optional controllers with `Get.isRegistered<X>()`.

**Folder layout to mirror**
```
lib/
  bindings/<feature>/
  common/widgets/{appbar,buttons,dialogs,icons,layout,loaders,shapes,tiles,toast}/
  data/{repositories/<domain>,services,database}/
  features/<feature>/{controllers,models,screens/{widgets},services}/
  routes/{routes.dart,app_routes.dart}
  utils/{constants,exceptions,helpers,themes,validators,formatter,network_manager}/
```

---

# PHASE 1 — SQL migration (do this first; nothing else works without it)

> **Prompt to paste:**
>
> Write a single idempotent Supabase migration at `supabase/migrations/0001_admin_foundation.sql` for the MatricMate project described in Phase 0. It must be safe to run against a live database that already contains `users`, `payment_receipts`, `notifications`, `user_sessions`, `subjects`, `chapters`, `tests`, `questions`, `passages`, and `question_sections` — so use `IF NOT EXISTS` / `ADD COLUMN IF NOT EXISTS` throughout and never drop or rewrite existing data.
>
> Include, in this order:
>
> **1. Admin identity**
> ```sql
> CREATE TABLE IF NOT EXISTS admins (
>   firebase_uid text PRIMARY KEY,
>   email        text NOT NULL UNIQUE,
>   display_name text,
>   role         text NOT NULL DEFAULT 'admin'
>                CHECK (role IN ('admin','superadmin')),
>   is_active    boolean NOT NULL DEFAULT true,
>   created_at   timestamptz NOT NULL DEFAULT now(),
>   last_login_at timestamptz
> );
> ```
>
> **2. Payment review state** — add to `payment_receipts`: `id bigserial PRIMARY KEY` if absent, `created_at timestamptz DEFAULT now()`, `status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected'))`, `amount numeric(10,2)`, `currency text DEFAULT 'ETB'`, `reviewed_by text REFERENCES admins(firebase_uid)`, `reviewed_at timestamptz`, `rejection_reason text`. Backfill existing rows to `status='pending'`, `amount=250`, `currency='ETB'`. Index `(status, created_at DESC)` and `(user_id)`.
>
> **3. Immutable audit log**
> ```sql
> CREATE TABLE IF NOT EXISTS admin_audit_log (
>   id          bigserial PRIMARY KEY,
>   admin_uid   text NOT NULL,
>   action      text NOT NULL,   -- 'approve_payment' | 'reject_payment' | 'broadcast'
>                                -- | 'edit_user' | 'create_test' | 'delete_question' | ...
>   entity_type text NOT NULL,   -- 'payment_receipt' | 'user' | 'test' | 'question' | ...
>   entity_id   text,
>   before      jsonb,
>   after       jsonb,
>   note        text,
>   created_at  timestamptz NOT NULL DEFAULT now()
> );
> ```
> Index `(created_at DESC)` and `(admin_uid, created_at DESC)`.
>
> **4. Close the analytics gap** — a synced attempt table, because `results` is currently device-local only. Note the deliberate differences from local SQLite: a real attempt timestamp, an explicit question count so scores don't require decoding a JSON blob, and **no** `UNIQUE(user_id, test_id)` so attempt history survives.
> ```sql
> CREATE TABLE IF NOT EXISTS test_attempts (
>   id             bigserial PRIMARY KEY,
>   user_id        text NOT NULL,
>   test_id        integer NOT NULL,
>   subject_id     integer,
>   test_type      text,
>   grade          integer,
>   correct_count  integer NOT NULL,
>   question_count integer NOT NULL,
>   score_pct      numeric(5,2) GENERATED ALWAYS AS
>                  (CASE WHEN question_count > 0
>                        THEN round(correct_count::numeric * 100 / question_count, 2)
>                        ELSE 0 END) STORED,
>   is_completed   boolean NOT NULL DEFAULT true,
>   duration_secs  integer,
>   attempted_at   timestamptz NOT NULL DEFAULT now(),
>   synced_at      timestamptz NOT NULL DEFAULT now()
> );
> ```
> Index `(attempted_at DESC)`, `(user_id, attempted_at DESC)`, `(subject_id)`, `(test_type)`.
>
> **5. Per-user read state for broadcasts** (fixes blocker 5)
> ```sql
> CREATE TABLE IF NOT EXISTS notification_reads (
>   notification_id bigint NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
>   user_id         text   NOT NULL,
>   read_at         timestamptz NOT NULL DEFAULT now(),
>   PRIMARY KEY (notification_id, user_id)
> );
> ```
>
> **6. Activity + signup metrics** — add `users.created_at timestamptz DEFAULT now()` if absent and `users.last_active_at timestamptz`. Add `notifications.created_by text REFERENCES admins(firebase_uid)` so broadcasts are attributable.
>
> **7. Aggregate RPCs** — `SECURITY DEFINER` functions so the dashboard makes one round trip instead of ten, each `REVOKE ... FROM anon` then `GRANT ... TO authenticated`:
> - `admin_kpis()` → total users, active/pending/inactive counts, stream split, pending-payment count, approved-revenue sum, attempts today/7d/30d, push-reachable count (non-null `fcm_token`)
> - `admin_signups_daily(days int)` → `(day date, count int)`
> - `admin_revenue_daily(days int)` → `(day date, amount numeric, count int)`
> - `admin_attempts_daily(days int)` → `(day date, attempts int, avg_score numeric)`
> - `admin_subject_performance()` → `(subject_id int, subject_name text, attempts int, avg_score numeric)`
> - `admin_test_type_distribution()` → `(test_type text, attempts int)`
> - `admin_funnel()` → signups → first attempt → payment submitted → approved
>
> **8. RLS** — enable on `admins`, `admin_audit_log`, `test_attempts`, `notification_reads`. Add a helper `is_admin()` returning whether `auth.jwt() ->> 'email'` matches an `is_active` row in `admins`. Policies: `anon` gets **no** access to `admins` or `admin_audit_log`; `test_attempts` allows insert by the owning client and select only via `is_admin()`. Add an explicit comment block listing the policies I still need to review manually for `users`, `payment_receipts`, and `user_sessions` — per Phase 0 those are currently writable by `anon`, which lets a user self-grant premium.
>
> Finish the file with a commented `-- ROLLBACK` section. Do not run it; print the SQL and tell me what to verify in the dashboard first.

**Acceptance:** the file exists, is idempotent, adds no destructive statement, and every new table has RLS enabled.

---

# PHASE 2 — Edge functions

> **Prompt to paste:**
>
> Two tasks in `supabase/functions/`, following the existing style of `send-push/index.ts` (Deno, `Deno.serve`, RS256 service-account JWT → FCM HTTP v1, `String()`-coerced data values, conditional spreads to drop `undefined` keys).
>
> **2a. Harden `send-push/index.ts`.** Add a shared-secret gate as the very first statement in the handler:
> ```ts
> if (req.headers.get("x-webhook-secret") !== Deno.env.get("PUSH_WEBHOOK_SECRET")) {
>   return new Response("unauthorized", { status: 401 });
> }
> ```
> Then add a third event to the `switch`:
> ```ts
> case "announcement": await handleAnnouncement(supabase, body); break;
> ```
> `handleAnnouncement` accepts `{event, title, body, audience: "all"|"stream"|"user", target_stream?, user_id?, payload?, created_by}` and maps audience onto the primitives that already exist:
>
> | audience | row inserted | FCM target |
> |---|---|---|
> | `all` | `user_id: null, target_stream: null` | topic `all_users` |
> | `stream` | `user_id: null, target_stream: 'natural'\|'social'` | topic `stream_natural` / `stream_social` |
> | `user` | `user_id: '<firebase_uid>', target_stream: null` | `sendFcmToToken(users.fcm_token)` |
>
> It must insert `type: 'announcement'`, `payload` as a **jsonb object** (not a string), `is_read` as a **boolean** (not 0/1), and send `data: {type: "announcement"}` so the client's `_handleTap` default branch routes to `Routes.notifications`. Return `{ok, notification_id, fcm_sent}` and log-but-don't-throw on FCM failure, matching the existing handlers. Also remove the `console.log` of the raw token if one exists.
>
> **2b. New function `admin-auth/index.ts`.** Takes a Firebase ID token, verifies it against Google's public certs (`https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com`, checking `aud`, `iss`, `exp`), looks the email up in `admins` where `is_active = true`, and on success returns a **Supabase JWT** signed with the project JWT secret whose claims include `sub` = the Firebase UID, `email`, `role: 'authenticated'`, and a custom `app_role` of `admin`/`superadmin`, expiring in 1 hour. Update `last_login_at`. Return 403 with a generic message on any failure — never leak whether the email exists. This is what makes `is_admin()` from Phase 1 work and what replaces `ensureSupabaseAuth()` in the admin app.
>
> Give me the `supabase secrets set` commands for `PUSH_WEBHOOK_SECRET` and any new secrets, and the deploy commands. Note in a comment that existing Postgres triggers calling `send-push` must be updated to send the new header, or pushes will start 401-ing.

**Acceptance:** `deno check` passes on both; `send-push` rejects a POST without the header; the two original events behave identically to before.

---

# PHASE 3 — Scaffold the admin project

> **Prompt to paste:**
>
> Create a **new sibling Flutter project** `matricmate_admin` next to `matricmate` (not a folder inside it — separate app id, separate Play listing, so an admin build never ships to students). Target **Android + Windows desktop** first; a wide layout matters more than phone ergonomics here.
>
> `pubspec.yaml` — mirror the parent's versions exactly so there is one dependency story: `get ^4.7.3`, `supabase_flutter ^2.12.2`, `firebase_core ^4.6.0`, `firebase_auth ^6.3.0`, `flutter_dotenv ^5.1.2`, `google_fonts ^6.2.1`, `iconsax_flutter ^1.0.1`, `intl ^0.20.2`, `connectivity_plus ^7.1.0`, `fluttertoast ^9.0.0`, `url_launcher ^6.3.1` (pinned, not `any`), `image_picker ^1.2.1`, `flutter_secure_storage ^10.0.0`, `get_storage ^2.1.1`, `http ^1.6.0`. **Do not** add `sqflite` (no offline cache — an admin tool should never show stale money), **do not** add `firebase_messaging`, and **do not** add a charting package: charts are hand-rolled per Phase 0.5. Add `include: package:flutter_lints/flutter.yaml` to `analysis_options.yaml` — the parent app is missing it, so don't repeat that.
>
> Copy verbatim from the parent, changing only import paths:
> `utils/constants/colors.dart`, `sizes.dart`, `utils/themes/**` (all 9 custom theme files + `app_theme.dart` + `theme_controller.dart`), `utils/exceptions/**` (all 8), `utils/helpers/helper_functions.dart`, `snackbar_helper.dart`, `toast_helper.dart`, `utils/validators/validators.dart`, `utils/formatter/formatter.dart`, `utils/network_manager/network_manager.dart`, `common/widgets/shapes/rounded_container.dart`, `common/widgets/loaders/**`, `common/widgets/dialogs/confirm_dialog_box.dart`, `common/widgets/toast/app_toast.dart`, `common/widgets/icons/circular_icon.dart`, `common/widgets/layout/grid_layout.dart`.
>
> `.env` (gitignored, **not** a bundled asset — the parent ships its `.env` inside the APK, don't repeat that): `SUPABASE_URL`, `SUPABASE_API_KEY`, `PUSH_WEBHOOK_SECRET`, `ADMIN_FUNCTIONS_BASE_URL`. Read them via `dotenv` at startup and fail loudly with a visible error screen if any is missing.
>
> `main.dart` — mirror the parent's ordering: `WidgetsFlutterBinding.ensureInitialized()` → `GetStorage.init()` → `dotenv.load()` → `Get.put(ThemeController(), permanent: true)` → `Firebase.initializeApp()` → `Supabase.initialize()` → `runApp(const AdminApp())`. **No** `FirebaseMessaging.onBackgroundMessage`.
>
> `app.dart` — `GetMaterialApp` wrapped in `Obx`, `initialBinding: AdminGeneralBinding()`, `theme`/`darkTheme` from `AppTheme`, `themeMode` from `ThemeController.instance`, `initialRoute: AdminRoutes.loading`, `getPages: AdminAppRoutes.pages`, `builder: (c, child) => ToastHost(child: child ?? const SizedBox())`.
>
> Create `routes/routes.dart` with an `AdminRoutes` class of `static const` strings: `loading '/loading'`, `login '/login'`, `shell '/shell'`, `dashboard '/dashboard'`, `payments '/payments'`, `paymentDetail '/payments/detail'`, `notifications '/notifications'`, `notificationCompose '/notifications/compose'`, `users '/users'`, `userDetail '/users/detail'`, `content '/content'`, `contentSubject '/content/subject'`, `contentChapter '/content/chapter'`, `contentTest '/content/test'`, `contentQuestion '/content/question'`, `sessions '/sessions'`, `auditLog '/audit-log'`, `settings '/settings'`. Add `routes/app_routes.dart` with an empty `AdminAppRoutes.pages` list plus the `appRouteObserver`, and stub screens so the app compiles and runs.
>
> Run `flutter analyze` and `flutter run -d windows`; it must boot to a blank themed loading screen with zero analyzer issues.

**Acceptance:** app boots, theme matches the parent side by side, `flutter analyze` is clean, `.env` is gitignored.

---

# PHASE 4 — Admin auth and the role gate

> **Prompt to paste:**
>
> Build admin authentication. **Do not copy `ensureSupabaseAuth()`** — anonymous Supabase auth is exactly what makes admin RLS impossible (Phase 0.1). Replace it with the real session from `admin-auth`.
>
> `data/repositories/admin_auth_repository.dart`
> - `Future<UserCredential> loginWithEmailAndPassword(String email, String password)` — Firebase Auth, wrapped in the standard `try/catch` → `AppExceptionHandler.handle(e)`.
> - `Future<String> exchangeForSupabaseJwt()` — `FirebaseAuth.instance.currentUser!.getIdToken(true)`, POST it to `${ADMIN_FUNCTIONS_BASE_URL}/admin-auth`, return the Supabase JWT.
> - `Future<AdminModel> fetchAdminProfile(String uid)` — `from('admins').select().eq('firebase_uid', uid).maybeSingle()`; throw a clear `AppFailure(title: 'Access Denied', message: 'This account is not an administrator.')` if null or `is_active == false`.
> - `Future<void> logout()` — Firebase sign-out **and** Supabase sign-out **and** clear the cached JWT. (The parent app has two divergent logout paths and the one users press is incomplete — do not reproduce that. One path only.)
>
> `features/auth/models/admin_model.dart` — `AdminModel {firebaseUid, email, displayName, role, isActive, createdAt, lastLoginAt}` with `fromJson`/`toJson` using the exact snake_case column names from Phase 1, plus `bool get isSuperAdmin => role == 'superadmin'` and an `AdminModel.empty()`.
>
> `data/services/admin_session_service.dart` — holds the current `AdminModel` and Supabase JWT, refreshes the JWT before expiry (it lives 1 hour), and exposes `Rx<AdminModel> admin` plus `bool get isAuthenticated`. Store the JWT in `flutter_secure_storage`, never `GetStorage`. **Do not persist the password** — the parent app's "remember me" stores it, and that's unnecessary since Firebase persists sessions itself.
>
> `features/auth/controllers/admin_login_controller.dart` — `GetxController` with `emailController`, `passwordController`, `formKey`, `isLoading.obs`, `hidePassword.obs`. `login()` validates → `NetworkManager` connectivity check → Firebase login → JWT exchange → profile fetch → role check → `Get.offAllNamed(AdminRoutes.shell)`. On any failure: `AppExceptionHandler.handleResponse(e)`, sign out completely, stay on the login screen. Reuse `AppValidator.validateEmail` / `validateEmptyText`.
>
> `features/auth/screens/admin_login_screen.dart` — a centred card (max width 420) on the themed scaffold using the Phase 0.5 card idiom: app logo, "MatricMate Admin", email + password fields, a show/hide toggle, a full-width teal `ElevatedButton` with an inline spinner while `isLoading`, and a "Forgot password?" link calling `sendResetPasswordEmail`. **No signup link — admin accounts are provisioned by SQL only.**
>
> `features/auth/screens/admin_loading_screen.dart` — on init, if a Firebase session exists, silently re-exchange the JWT and re-verify the admin row, then route to `shell`; otherwise to `login`. Show the parent app's pulsing-dots loader.
>
> Add a `RoleGuard` mixin or `GetMiddleware` that redirects to `login` when `!isAuthenticated`, and a `requireSuperAdmin` check for destructive actions. Wire all of it into `AdminGeneralBinding` with `Get.put(..., permanent: true)`.
>
> Also give me the SQL to insert my own admin row so I can actually log in.

**Acceptance:** a non-admin Firebase account is rejected with "Access Denied"; a valid admin lands on the shell; killing and reopening the app restores the session without re-login; logout leaves no session behind.

---

# PHASE 5 — App shell and navigation

> **Prompt to paste:**
>
> Build the admin shell. The parent app uses a floating pill bottom nav for 5 phone tabs; an admin tool needs a **persistent left sidebar** on wide screens instead, falling back to a drawer under 900px.
>
> `features/shell/controllers/admin_nav_controller.dart` — `selectedIndex.obs`, an `IndexedStack` of pages (so tab state survives switching), `changePage(int)`, and a `pendingPaymentCount.obs` + `unreadAlertCount.obs` for sidebar badges, refreshed by the Phase 7 realtime subscription.
>
> `features/shell/screens/admin_shell.dart` — `LayoutBuilder`: `>= 900px` renders a fixed 260px sidebar beside the body; below that, a `Drawer` plus a hamburger `Appbar`. Sidebar items, in order, with `iconsax_flutter` icons: Dashboard (`Iconsax.chart_2_copy`), Payments (`Iconsax.receipt_copy`, badge = pending count), Notifications (`Iconsax.notification_copy`), Users (`Iconsax.people_copy`), Content (`Iconsax.book_copy`), Sessions (`Iconsax.mobile_copy`), Audit Log (`Iconsax.document_text_copy`), Settings (`Iconsax.setting_2_copy`).
>
> Style the selected item like the parent's nav button: `AnimatedContainer` 200ms `Curves.easeInOut`, background `AppColors.primary.withValues(alpha: 0.12)`, `borderRadius: 22`, icon and label in `AppColors.primary`; unselected icons `dark ? Colors.white54 : AppColors.darkGrey`. Sidebar surface `dark ? AppColors.darkCard : AppColors.white` with the standard card shadow.
>
> Sidebar footer: the signed-in admin's name, email, role chip, a theme toggle bound to `ThemeController`, and a Logout item that goes through `ConfirmDialogBox` first.
>
> Add a shared `AdminScaffold({required String title, List<Widget>? actions, required Widget body})` that every feature screen uses, so page padding (`AppSizes.defaultSpace`), max content width (`1200`), and the section header style are defined once. Also add `common/widgets/admin_data_table.dart` — a reusable paginated table with sortable columns, a per-row action slot, empty and loading states, and horizontal scroll on narrow widths. Every list screen in Phases 6–11 uses it; do not hand-roll a second table.
>
> Register every route from Phase 3 in `AdminAppRoutes.pages` with its binding, guarded by the Phase 4 middleware.

**Acceptance:** sidebar collapses to a drawer below 900px, tab state survives switching, badges render, logout confirms first.

---

# PHASE 6 — Dashboard and analytics

> **Prompt to paste:**
>
> Build the analytics dashboard on the Phase 1 RPCs. **Read Phase 0.4 blocker 1 first:** learning metrics only exist for users who have synced to `test_attempts`. Every chart fed by that table must render an explicit "No synced attempt data yet — see Phase 12" empty state rather than a misleading zero, and the dashboard must show a one-line banner stating what share of users have ever synced an attempt. Do not silently present partial data as complete.
>
> `data/repositories/admin_analytics_repository.dart` — one method per RPC: `fetchKpis()`, `fetchSignupsDaily(int days)`, `fetchRevenueDaily(int days)`, `fetchAttemptsDaily(int days)`, `fetchSubjectPerformance()`, `fetchTestTypeDistribution()`, `fetchFunnel()`, plus `fetchContentInventory()` (counts of subjects/chapters/tests/questions/passages via `count: CountOption.exact`). Standard try/catch → `AppExceptionHandler.handle(e)`.
>
> `features/dashboard/controllers/dashboard_controller.dart` — `isLoading.obs`, `Rx<AdminKpis>`, the series lists, and a `rangeDays.obs` of 7/30/90. `loadAll()` fans out with `Future.wait` (the parent's `AnalyticsController.loadAll()` is the pattern to copy). Re-run on range change. Add `refreshAll()` for pull-to-refresh and an auto-refresh every 60s while the tab is visible.
>
> `features/dashboard/models/` — `AdminKpis`, `DailyPoint {DateTime day, num value, num? secondary}`, `SubjectPerf`, `FunnelStage`.
>
> **Screen layout** (`dashboard_screen.dart`), all cards using the Phase 0.5 idiom:
> 1. **KPI row** — responsive `GridView.count` (4 columns ≥1200px, 2 below): Total Users, Active Subscribers (with % of total), Pending Payments (tappable → Payments, tinted `warning` when > 0), Revenue (ETB, sum of approved), Attempts (24h), Push Reach %. Each tile: icon in a tinted circle, big value, label in `textSecondary`, and a small delta vs the previous period.
> 2. **Signups over time** — the hand-rolled line chart from Phase 0.5, with a 7/30/90 segmented control.
> 3. **Revenue over time** — bar chart (rounded top corners, `success` fill), with the ETB total for the range.
> 4. **Subscription funnel** — horizontal stacked bar: inactive → pending → active, using `error`/`warning`/`success`, with counts and percentages.
> 5. **Subject performance** — `LinearProgressIndicator` rows with the `>=70 success / >=50 warning / else error` ramp, sorted worst-first (admins care about weak subjects, the inverse of the student app's sort).
> 6. **Test-type distribution** — the 110×110 donut with the fixed colour map `chapter→primary, entrance→info, model→success, grade→warning` plus a dot legend.
> 7. **Stream split** — small donut for natural / social / common.
> 8. **Content inventory** — a compact table of row counts per content table with a "Manage" link to Phase 10.
>
> Extract each section into its own file under `features/dashboard/screens/widgets/`, mirroring the parent's analytics folder. Put both `CustomPainter`s in `common/widgets/charts/` (`line_chart_painter.dart`, `donut_chart_painter.dart`) so Phases 7–11 can reuse them.
>
> Add a CSV export button that downloads the current range's series via `url_launcher` or writes to disk on desktop.

**Acceptance:** every card renders with real data or an honest empty state; range switching refetches; no chart package in `pubspec.yaml`; the sync-coverage banner is visible.

---

# PHASE 7 — Payment review queue (accept / reject)

> **Prompt to paste:**
>
> Build the payment review queue. This is the highest-stakes screen in the app — it moves money and it flips premium access — so correctness beats polish. Re-read Phase 0.4 blockers 3 and 4.
>
> `data/repositories/admin_payment_repository.dart`
> - `Future<List<PaymentReview>> fetchQueue({required String status, String? search, String? method, DateTimeRange? range, int page = 0, int pageSize = 25})` — select `payment_receipts` joined to `users` (`user_id → users.id`) so one query yields receipt + name + email + current `subscription_status`. Order `created_at DESC`, paginate with `.range()`.
> - `Future<int> countByStatus(String status)`.
> - `Future<PaymentReview> fetchDetail(int id)`.
> - **`Future<void> approve({required int receiptId, required String userId, required String adminUid, num? amount})`** — the critical path. In order: (1) `payment_receipts` → `status='approved'`, `reviewed_by`, `reviewed_at=now()`, `amount`; (2) `users` → `subscription_status='active'`; (3) insert `admin_audit_log` with `before`/`after`; (4) POST the push. Steps 1–3 must go through a single `rpc('admin_approve_payment', ...)` so they are atomic — if the push fails afterwards, the DB is still consistent and the client picks the change up over Realtime anyway. Write that RPC as a `supabase/migrations/0002_payment_rpcs.sql`.
> - **`Future<void> reject({required int receiptId, required String userId, required String adminUid, required String reason})`** — same shape via `admin_reject_payment`. Per blocker 4, write **`subscription_status='inactive'`, not `'rejected'`** — `'rejected'` makes all three `UserModel` getters return false and drops the student into a UI dead zone. Store the reason in `payment_receipts.rejection_reason` and pass it in the push payload. Add a code comment explaining exactly why.
> - `Future<String> signedReceiptUrl(String path)` — the `receipts` bucket is currently public; prefer `createSignedUrl(path, 300)` and note in a comment that the bucket should be flipped to private.
> - `Future<void> sendPaymentPush({required String userId, required String status, String? reason})` — POST to `send-push` with `{event: 'payment_status', user_id, status}` **and the `x-webhook-secret` header** from Phase 2a.
>
> `features/payments/models/payment_review.dart` — `PaymentReview {id, userId, userName, userEmail, userStream, subscriptionStatus, receiptPath, receiptUrl, verificationUrl, paymentMethod, amount, currency, status, createdAt, reviewedBy, reviewedAt, rejectionReason}`, `fromJson` handling the nested `users` join object and tolerating nulls the way the parent's models do (`json['x']?.toString() ?? ''`).
>
> `features/payments/controllers/payments_controller.dart` — tabs `pending` / `approved` / `rejected` / `all` with counts, `searchQuery.obs` (debounced 300ms, matched against name/email/`user_id`), method filter, date range, pagination, `isLoading.obs`, `isActing.obs` keyed by receipt id so one row's spinner doesn't freeze the table. **Subscribe to Realtime on `payment_receipts` INSERT** so a new submission appears without a refresh and the sidebar badge increments. Keep `PostgresChangeFilter` usage in line with the parent's `RealtimeService`, and remember the parent's note that Realtime supports only a single `eq()` filter.
>
> **`payments_screen.dart`** — `AdminScaffold` + status tabs + filter bar + `AdminDataTable`: Date, Student (name over email), Method (coloured chip), Amount, Status (pill: `warning` pending / `success` approved / `error` rejected), Actions. Row tap opens the detail panel — a side sheet ≥1200px, a full route below.
>
> **`payment_detail_screen.dart`** — two panes. Left: the receipt image with pinch/scroll zoom, a rotate control, and an "Open original" button; show a clear placeholder when the image 404s (receipts are always saved as `.jpg` even when the user picked a PNG or PDF, so broken images are expected). Right: student identity card (with a link to their Phase 9 detail page), current subscription status, payment method + the account number it should have gone to, the `verification_url` as a tappable link, an editable amount defaulting to 250 ETB, submission timestamp, and — if already reviewed — who reviewed it and when.
>
> Footer actions: **Approve** (green, opens `ConfirmDialogBox` summarising student + amount, then acts) and **Reject** (red, opens a dialog requiring a reason — offer presets "Receipt unreadable", "Amount incorrect", "Transaction not found", "Duplicate submission", plus free text; block submit while empty). Both disable while `isActing`, show a success toast, log to the audit table, and advance to the next pending item so a reviewer can work the queue without returning to the list. Add keyboard shortcuts: `A` approve, `R` reject, `J`/`K` next/previous.
>
> Guard against double-action: re-read `status` immediately before writing and abort with "Already reviewed by <admin>" if it changed.

**Acceptance:** approving flips `subscription_status` to `active` and the student's app updates live over Realtime; rejecting writes `inactive` + a reason and pushes; both write an audit row; a receipt cannot be actioned twice; approve and reject are atomic (kill the app mid-action and the DB is consistent).

---

# PHASE 8 — Notification composer and history

> **Prompt to paste:**
>
> Build notification management on the `announcement` event from Phase 2a.
>
> `data/repositories/admin_notification_repository.dart`
> - `Future<void> sendAnnouncement({required String title, required String body, required String audience, String? targetStream, String? userId, Map<String, dynamic>? payload, required String adminUid})` — POST to `send-push` with `event: 'announcement'` and the `x-webhook-secret` header.
> - `Future<void> sendContentAnnouncement({required int testId, required int subjectId, required String testType, ...})` — the existing `new_test` event, so an admin can manually re-announce content. Emit **`test_type`** (the client prefers it over `type`) and make **every data value a String**.
> - `Future<List<AppNotificationAdmin>> fetchHistory({String? type, String? audience, int page, int pageSize})` and `Future<Map<String,int>> fetchDeliveryStats(int notificationId)` — reach counted from `notification_reads` once Phase 1 is applied.
> - `Future<void> deleteNotification(int id)` — there is no delete path today and broadcasts accumulate forever; add one.
> - `Future<int> fetchPushReachableCount({String? stream})` — `users` with non-null `fcm_token`, so the composer can state real reach before sending.
>
> `features/notifications/models/app_notification_admin.dart` — `{id, userId (nullable), title, body, type, targetStream, payload, isRead, createdAt, createdBy, readCount}`. **Do not reuse the student app's `AppNotification.toMap()`** for writes: it emits `payload` as a JSON *string* and `is_read` as `0`/`1`, which is SQLite-shaped and wrong for Postgres (`jsonb` + `boolean`). Note that in a comment.
>
> `features/notifications/controllers/notification_compose_controller.dart` — `titleController`, `bodyController`, `audience.obs` (`all` / `stream` / `user`), `targetStream.obs`, `selectedUser.obs`, `type.obs` (`announcement` / `new_content`), an optional deep-link payload builder, `isSending.obs`, and `estimatedReach.obs` recomputed whenever audience changes. Validate: title ≤ 65 chars, body ≤ 240, both non-empty, a user selected when audience is `user`, a stream selected when audience is `stream`.
>
> **`notification_compose_screen.dart`** — left column: audience selector (segmented), a searchable user picker when audience is `user`, a stream dropdown when `stream`, title and body fields with live character counters, a type selector, and a collapsible "Deep link" section that builds a `new_content` payload from subject/test pickers and emits the exact keys the client's `NotificationTestOpener` needs (`test_type`, `test_id`, `subject`, `subject_id`, `grade`, `chapter`, `chapter_id`, `chapter_number`).
>
> Right column: a **live phone-frame preview** of both the OS push and the in-app tile — replicate the tile's real styling (icon by type: `Icons.campaign_rounded` announcement / `Icons.receipt_long_rounded` payment / `Icons.menu_book_rounded` new_content; primary-coloured border and an 8×8 dot while unread). Below it, a reach summary: *"Sends to ~N devices (M users have no FCM token and will only see it in-app)."*
>
> Send button: `ConfirmDialogBox` that names the audience and count in plain words ("This will push to **all 1,240 users**. Continue?"), then send, toast, log to audit, clear the form.
>
> **`notifications_history_screen.dart`** — `AdminDataTable` of past notifications: date, type chip, audience ("All" / "Stream: natural" / a single user's email), title, read count, sender, delete action. Row tap shows the full body and payload JSON.
>
> Finally, add a prominent inline warning card on the history screen restating Phase 0.4 blocker 5: until `notification_reads` is live in the client, broadcast read state is shared and the first student to tap marks a broadcast read for everyone. Link it to Phase 12.

**Acceptance:** an `all` broadcast reaches a test device and appears in-app; a single-user notification reaches only that user; a `new_content` push with a real `test_id` deep-links into the right test screen; every send writes an audit row.

---

# PHASE 9 — User management

> **Prompt to paste:**
>
> `data/repositories/admin_user_repository.dart`
> - `Future<List<AdminUserRow>> fetchUsers({String? search, String? status, String? stream, String? sortBy, bool desc, int page, int pageSize})` — search across `first_name`, `last_name`, `email`, `id` using `.or('first_name.ilike.%q%,...')`. **Escape the query string** — the parent app's `AnalyticsController._buildWhere` interpolates filter values straight into SQL; do not copy that pattern here where values are typed by a human.
> - `Future<AdminUserDetail> fetchUserDetail(String uid)` — the `users` row plus their `payment_receipts` history, `user_sessions` row, `test_attempts` summary, and notification count.
> - `Future<void> updateSubscriptionStatus({required String uid, required String status, required String adminUid, String? note})` — a manual override for support cases (comp a subscription, revoke a fraudulent one). Restrict to `'active'` / `'inactive'` / `'pending'`, audit every call, and push a `payment_status` event so the student is told.
> - `Future<void> updateUserFields({required String uid, String? firstName, String? lastName, String? stream, required String adminUid})` — audited. Changing `stream` matters: it decides which FCM topic they're on and which subjects they see.
> - `Future<void> resetDeviceLock(String uid, String adminUid)` — clear `user_sessions.device_id` and/or top up `trial`; the single most common real support request, since the device id is a `SharedPreferences` UUID that resets on reinstall.
> - `Future<Map<String,dynamic>> exportUser(String uid)` — full JSON export for data-subject requests.
>
> `features/users/screens/users_screen.dart` — `AdminDataTable`: Name, Email, Stream chip, Status pill, Joined, Last active, Push (a filled/outline bell for token present/absent), Actions. Filter bar: status, stream, has-token, joined range, plus a debounced search. Show total and filtered counts. Add CSV export of the current filter.
>
> `features/users/screens/user_detail_screen.dart` — header card (avatar initials, name, email, status pill, stream, uid with copy button, joined, last active) then tabs:
> - **Overview** — attempt count, average score, last activity, subscription timeline
> - **Payments** — their receipt history with statuses, linking into Phase 7
> - **Activity** — their `test_attempts`, newest first, with per-subject scores
> - **Device** — `device_id`, remaining `trial`, and the Reset Device Lock action
> - **Notifications** — what they've been sent and read
>
> Action bar: Grant Premium / Revoke Premium / Set Pending (each behind `ConfirmDialogBox` with a mandatory note), Send Notification (prefills Phase 8's composer with audience `user`), Reset Device Lock, Export JSON. Restrict Revoke Premium and any destructive action to `superadmin` via the Phase 4 guard.

**Acceptance:** search and every filter work; granting premium updates the student's app live and pushes; reset device lock actually lets the student sign in on a new device; every mutation appears in the audit log.

---

# PHASE 10 — Content management

> **Prompt to paste:**
>
> Build CRUD over the content hierarchy `subjects → chapters → tests → questions`, plus `passages` and `question_sections`. This is what currently has no tooling at all — content presumably goes in through the Supabase dashboard by hand.
>
> **Critical invariants — violating any of these silently breaks the student app:**
> - `tests.type` ∈ `'chapter' | 'grade' | 'entrance' | 'model'`. `'entrance'` and `'model'` are downloaded by `downloadEntranceForSubject`; `'chapter'` and `'grade'` by the chapter sync path. A wrong type means the test never reaches students.
> - `tests.time` is **minutes**, with `-1` meaning untimed. Never write `0`.
> - `tests.question_count` must equal the real number of `questions` rows for that test — the student UI trusts it. Recompute it on every question add/delete rather than letting an admin type it.
> - `questions.options` is a **JSON array of strings**; `correct_option_index` is **0-based** and must be `< options.length`. Validate both.
> - `questions.question_order` drives display order and starts at 1.
> - **`updated_at` is the entire delta-sync mechanism** for `tests`, `questions`, and `passages`. Every write must bump it or students never receive the edit. Add a DB trigger in `supabase/migrations/0003_updated_at_triggers.sql` rather than trusting client code, and verify existing triggers first.
> - `chapters` and `subjects` have **no** `updated_at` — they full-sync, so edits there propagate on the next sync regardless.
> - Question text supports the app's custom markup: `RichTextParser` for inline styling and `BBTableParser` for `[table]` blocks. The editor must preview using those same rules — copy `utils/helpers/rich_text_parser.dart` and `bb_table_parser.dart` and the `BBTableWidget` from the parent.
>
> `data/repositories/admin_content_repository.dart` — full CRUD per table, each audited, plus: `Future<void> recountTestQuestions(int testId)`, `Future<List<Map>> fetchQuestionsForTest(int testId)` (selecting `'*, question_sections(title)'` exactly as the sync path does), `Future<void> reorderQuestions(int testId, List<int> orderedIds)`, and `Future<String> uploadContentImage(XFile file, String folder)` targeting a **new** `content` bucket (not `receipts`), preserving the real file extension and content type.
>
> Screens:
> - **`content_screen.dart`** — subject grid with per-subject counts (chapters, tests by type, questions) and natural/social/common chips. Create and edit subjects.
> - **`subject_detail_screen.dart`** — tabs for Chapters, Chapter Tests, Grade Tests, Entrance, Model. Chapter list is reorderable by `chapter_number`.
> - **`test_editor_screen.dart`** — form: title, type, subject, grade, chapter (only when type is `chapter`), time in minutes with an "Untimed" switch writing `-1`, and a read-only computed `question_count`. Then the question list: reorderable, showing order number, a text excerpt, an image/passage indicator, and the correct answer letter. Bulk actions: delete, move to another test, duplicate.
> - **`question_editor_screen.dart`** — the most important editor. Two panes: left is the form (question text with a markup toolbar, an image picker uploading to the `content` bucket, a dynamic options list of 2–6 entries with add/remove/reorder, a radio group choosing the correct option, `explanation_en`, `explanation_am`, an explanation image, an optional passage picker or inline creator, and a section title); right is a **live student-accurate preview** rendering exactly as `QuestionDetailBox` does — Lora 16px `height 1.75`, teal-tinted explanation box with the EN/አማ pill toggle, choice buttons, and `BBTableWidget` tables. Add Prev/Next to walk the test without leaving the editor, and warn on unsaved changes.
> - **`passages_screen.dart`** — CRUD over `passages` (`content`, `title`, `image_url`) showing which questions reference each one; block deletion while referenced (`questions.passage_id` is `ON DELETE SET NULL`, which would silently orphan the question).
>
> Add a **JSON/CSV bulk importer**: upload a file, validate every row against the invariants above, show a per-row diff preview with errors flagged, and commit only on confirm — inside one transaction. Include a downloadable template. Add an "Announce" button on a saved test that fires the Phase 8 `new_test` push.
>
> Every destructive delete requires typed confirmation of the entity name and is `superadmin`-only. `questions` cascade-delete from `tests`, so deleting a test destroys its questions — say so explicitly in the dialog.

**Acceptance:** creating a test and questions makes them appear in the student app after a sync; `question_count` always matches reality; `updated_at` bumps on every edit; the preview is visually identical to the student render; a bad bulk import is rejected wholesale, not half-applied.

---

# PHASE 11 — Sessions, audit log, settings

> **Prompt to paste:**
>
> Three smaller screens.
>
> **Sessions** (`features/sessions/`) — an `AdminDataTable` over `user_sessions` joined to `users`: email, `device_id`, remaining `trial`, last change. Filters for exhausted trials (`trial = 0`) and recently changed devices. Actions: Reset Device (clear `device_id`), Grant Extra Trials (+N, audited), and a bulk reset for a selection. Add an inline note that the device id is a `SharedPreferences` UUID that resets on reinstall, so this lock is soft and a determined user can bypass it by clearing app data — the fix is `flutter_secure_storage` in the student app (Phase 12).
>
> **Audit log** (`features/audit/`) — a read-only reverse-chronological table over `admin_audit_log`: timestamp, admin email, action chip, entity type + id, note. Filters by admin, action, entity type, date range. Row expands to a **before/after JSON diff** with changed keys highlighted. CSV export. This table is append-only — offer no edit or delete affordance anywhere.
>
> **Settings** (`features/settings/`) —
> - *Profile*: the signed-in admin's name and email, change password via Firebase, theme toggle.
> - *Admins* (superadmin only): list `admins`, invite by email (insert a row — note that they must also exist in Firebase Auth), toggle `is_active`, change role. Never allow an admin to deactivate or demote themselves.
> - *App config*: surface the values currently hardcoded in the student app so an admin can see what shipping a new build would take — premium price `250 ETB` (`premium.dart:56`), the four payment accounts (`payment_enum.dart`: telebirr `0983878287`, CBE `1000786878626`, Abyssinia `187978686`, M-PESA `0783738782`, all "Beshasha Desmon"), the Telegram support handle `t.me/matric_mate` (`app_strings.dart:37`), and the free-tier limits (entrance `index < 2`, chapter tests `index < 3`, grade tests `index < 1`). Mark each read-only with a "requires an app release to change" note, and add a recommendation to move them into an `app_config` table.
> - *Diagnostics*: Supabase connectivity, edge-function reachability (ping `send-push` and expect the 401 that proves the secret gate is live), FCM project id, and the count of users without a token.

**Acceptance:** device reset unblocks a real student login; audit rows are visibly immutable; a superadmin cannot lock themselves out.

---

# PHASE 12 — Close the loop in the student app

> **Prompt to paste:**
>
> The admin app is only as honest as the data it reads. Make these changes **in the parent `matricmate` app** so the dashboard stops being partly blind. Keep each one small and independently shippable.
>
> 1. **Sync test attempts.** After `ResultController` finalises a completed attempt, insert into Supabase `test_attempts` (`user_id`, `test_id`, `subject_id`, `test_type`, `grade`, `correct_count`, `question_count`, `is_completed`, `duration_secs`, `attempted_at`). Queue failed inserts locally and retry on next connectivity, so offline attempts aren't lost. This is what makes Phase 6's learning charts real. Note the local `results` table has `UNIQUE(user_id, test_id)` and keeps only the latest attempt — the remote table deliberately does not, so history accumulates there.
> 2. **Add a real attempt timestamp locally.** `results` has no `created_at`, so `AnalyticsController` currently filters and sorts by **`tests.created_at`** — when the test was *authored*, not when the student sat it. "Last 7 days" today means "tests authored in the last 7 days". Add `results.attempted_at`, bump the DB version with a migration, and switch the time filter and score-trend ordering onto it.
> 3. **Track activity.** Update `users.last_active_at` on app foreground (throttled to once per hour) so DAU/MAU becomes computable.
> 4. **Per-user read state.** Write to `notification_reads` instead of mutating the shared `notifications.is_read` for broadcast rows, and compute unread by joining against it. This fixes both halves of blocker 5 — global read-through and the `markAllRead` revert.
> 5. **Key push-inserted rows on the server id.** `fcm_service.dart:151` uses `message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch`, which never equals the Supabase `bigint` — so pushed notifications duplicate after the next sync and `markRead` updates a nonexistent id. Send the real id in the FCM data payload and use it.
> 6. **Persist notifications from background pushes.** `firebaseMessagingBackgroundHandler` is currently an empty no-op.
> 7. **Delete the token log** — `fcm_service.dart:83` logs the raw FCM token, and `dart:developer log()` is **not** stripped in release builds.
> 8. **Unify logout.** `UserController.logOut()` (what the profile screen actually calls) skips `RealtimeService.stop()`, `FcmService.unsubscribeAll()`, clearing sync timestamps, and Supabase sign-out — all of which `AuthenticationController.logout()` does. Collapse to one path so topics and channels don't leak after logout.
> 9. **Scope the local user row.** `UserRepository.loadLocalUser()` does `db.query('user', limit: 1)` on a table keyed by `id`, and neither logout path clears it — so after account A logs out and B logs in, B can see A's name and premium badge offline. Filter by the current Firebase uid and clear user-scoped tables on logout.
> 10. **Handle `'rejected'`** in `UserModel` if you'd rather the admin write that value than `'inactive'` — otherwise all three status getters return false and the student sees a blank state.
> 11. **Sync-window cap.** `notification_repository.dart:41` caps sync at `.limit(100)` with no expiry path; broadcasts accumulate forever and older ones fall off. Add pagination or retention.
>
> Do these one at a time with a test for each. Items 1–4 unblock the admin dashboard; 5–11 are correctness fixes that the admin tool will otherwise expose to you as confusing data.

---

# PHASE 13 — Hardening and release

> **Prompt to paste:**
>
> Finish the admin app.
>
> **Security** — audit that no admin write path is reachable with only the anon key; confirm `admins` and `admin_audit_log` are unreadable by `anon`; flip the `receipts` bucket to private and serve signed URLs; confirm `send-push` 401s without the secret; add a rate limit on `admin-auth` to blunt credential stuffing; make sure no secret is bundled as a Flutter asset (the parent ships `.env` inside its APK — don't repeat that); add a session idle timeout of 30 minutes with a re-auth prompt.
>
> **Tests** — unit-test `AdminPaymentRepository.approve`/`reject` including the double-action guard and audit write; the `AdminUserRepository` search escaping; every model's `fromJson` against null-heavy payloads; the Phase 10 content validators (options/correct index, `question_count`, `tests.type`, `time = -1`); and widget tests for the payment queue and the notification composer's validation. The parent app's 65 tests are model/util-heavy and cover none of the payment flow — cover it here.
>
> **Error handling and empty states** — every screen needs loading, empty, and error states. Never render `0` where the truth is "not measurable" (Phase 0.4 blocker 1). Add an offline banner via `NetworkManager`.
>
> **Release** — a real application id (`com.matricmate.admin`, never `com.example.*`), a release signing config reading from a gitignored `key.properties`, `isMinifyEnabled` and `isShrinkResources` on, `--obfuscate --split-debug-info`, and `firebase_crashlytics` with a `FlutterError.onError` hook. Distribute internally only — Play internal testing or direct APK, never a public listing.
>
> **Docs** — a `README.md` covering setup, the `.env` keys, how to provision an admin (the SQL insert plus the Firebase Auth account), how to deploy the edge functions, and a runbook for the two most common support tasks: approving a payment and resetting a device lock.

**Acceptance:** `flutter analyze` clean, all tests green, a release build installs and works against production, and no admin action is possible with the anon key alone.

---

## Suggested order

Phases **1 → 2 → 3 → 4 → 5** are strictly sequential. After the shell exists:

| Priority | Phase | Why |
|---|---|---|
| 1 | **7 — Payments** | The only thing that currently *requires* manual SQL. Highest daily value. |
| 2 | **8 — Notifications** | Unblocks announcements, which have no path today at all. |
| 3 | **9 — Users** | Support requests (device locks, comped subscriptions). |
| 4 | **12 items 1–4** | Without these, Phase 6's charts are empty by construction. |
| 5 | **6 — Dashboard** | Build after real data exists, so you're not designing against zeros. |
| 6 | **10 — Content** | Largest surface; the Supabase dashboard is a workable stopgap. |
| 7 | **11, 12 rest, 13** | Polish, correctness, release. |

## What I could not verify

- **The real DDL.** `supabase/` holds only `functions/`; there are no migrations. Every remote column list here is reconstructed from Dart call sites, so there may be columns the app never touches. Dump the schema (`supabase db dump --schema public`) and commit it before generating code against Phase 0.2.
- **RLS policies.** Unknown. If `users` is `anon`-writable, a student can self-grant premium and any admin approval workflow is theatre. Check this first — it changes how much of Phase 1's §8 you need.
- **The Postgres triggers that call `send-push`.** The function's header comment references `sql/notifications_schema.sql`, which does not exist in the repo. If those triggers live only in the remote database, Phase 2a's secret header will break them until they're updated.
