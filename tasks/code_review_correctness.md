## Summary
Six correctness bugs found across four files — two are critical (silent data loss / crash under normal use), the rest are high/medium severity.

---

## Issues

---

### BUG 1 — CRITICAL | `profile_provider.dart` `updateProfile` — `toJson()` sends `created_at` to Supabase UPDATE, which will be rejected or silently overwrite a server-managed column

**File:** `lib/presentation/providers/profile_provider.dart`, line 60
**Also affects:** `wardrobe_repository.dart` `updateItem` (line 67–70) and `calendar_repository.dart` `updateEvent` (line 54–58)

`Profile.toJson()` always includes `'created_at': createdAt.toIso8601String()`.
When that map is passed directly to `.update(profile.toJson())`, Supabase will
attempt to write the client-supplied timestamp back into the row. Two failure modes:

1. If the column has a `DEFAULT now()` but is otherwise writable, it silently
   overwrites the real server timestamp with whatever the client holds — which
   may be stale or wrong after a `copyWith` chain.
2. If the column is protected by a trigger or a `CHECK` constraint, the request
   throws a `PostgrestException` and the update fails entirely.

`calendar_repository.createEvent` already does `json.remove('created_at')` before
insert. The same guard is missing from `updateEvent`, `updateProfile`, and
`updateItem`.

**Fix — all three update methods:** strip server-managed fields before sending.

```dart
// calendar_repository.dart  updateEvent
Future<CalendarEvent> updateEvent(CalendarEvent event) async {
  final json = event.toJson();
  json.remove('created_at');          // <-- add this
  final data = await _service.client
      .from(SupabaseTables.calendarEvents)
      .update(json)
      .eq('id', event.id)
      .select()
      .single();
  return CalendarEvent.fromJson(data);
}

// Same pattern for profile_provider.dart updateProfile and
// wardrobe_repository.dart updateItem — call toJson(), remove 'created_at',
// then pass the sanitised map to .update().
```

---

### BUG 2 — CRITICAL | `profile_provider.dart` `addProfile` — child profiles are inserted without `auth_user_id`, which passes RLS, but `deleteProfile` has no cascade guard — deleting the owning profile orphans wardrobe items

**File:** `lib/presentation/providers/profile_provider.dart`, line 101–107

`deleteProfile` calls `.delete().eq('id', profileId)` and then removes the profile
from local state. If the Supabase schema does not have `ON DELETE CASCADE` on
`wardrobe_items.profile_id → profiles.id` (not visible in the snippet but a
common omission), the DELETE will succeed (RLS allows it) and the wardrobe rows
will remain with a dangling `profile_id`. Those rows become permanently
inaccessible: the RLS SELECT policy for `wardrobe_items` requires
`profile_id IN (SELECT id FROM profiles WHERE household_id = current_household_id())`,
and the profile no longer exists. The data is silently stranded in the database.

Additionally, there is no guard preventing deletion of the household owner's
profile (the one with a non-null `auth_user_id`). Deleting it will break
`current_household_id()` for the entire household because that function resolves
via `profiles.auth_user_id = auth.uid()`.

**Fix:** Before deleting, check whether the profile is the auth owner and refuse
if so. Confirm `ON DELETE CASCADE` exists on `wardrobe_items` and `outfits` in
`supabase_schema.sql`, or manually delete child rows before deleting the profile.

```dart
Future<void> deleteProfile(String profileId) async {
  final profiles = state.value ?? [];
  final target = profiles.firstWhere((p) => p.id == profileId,
      orElse: () => throw StateError('Profile not found'));
  if (target.authUserId != null) {
    throw StateError('Cannot delete the household owner profile.');
  }
  final svc = ref.read(supabaseServiceProvider);
  await svc.client.from(SupabaseTables.profiles).delete().eq('id', profileId);
  state = AsyncData<List<Profile>>(
    <Profile>[...profiles]..removeWhere((p) => p.id == profileId),
  );
}
```

---

### BUG 3 — HIGH | `profile_provider.dart` `copyWith` nullable-field erasure — `updateProfile` cannot clear `avatarUrl` or `authUserId`

**File:** `lib/data/models/profile.dart`, lines 68–90

`Profile.copyWith` uses `??` for every field:

```dart
authUserId: authUserId ?? this.authUserId,
avatarUrl:  avatarUrl  ?? this.avatarUrl,
```

Passing `null` explicitly (e.g., `profile.copyWith(avatarUrl: null)`) is
indistinguishable from omitting the parameter — both keep the existing value.
There is no way to clear a nullable field. The same defect exists in
`CalendarEvent.copyWith` for `occasion` and `notes`, and in `WardrobeItem.copyWith`
for `brand`, `size`, `aiDescription`, `imageUrl`, `processedImageUrl`.

In practice this causes a silent bug when a user removes a brand label or
occasion from an item — the old value is silently preserved on the next
`updateItem` / `updateEvent` call if `copyWith` was used to build the updated
object.

**Fix (sentinel pattern, same as `AuthState.copyWith`):**

```dart
// Define a private sentinel at the top of the file
const _kKeep = Object();

// In copyWith, use Object? with a default of _kKeep:
Profile copyWith({
  Object? avatarUrl = _kKeep,
  ...
}) {
  return Profile(
    avatarUrl: identical(avatarUrl, _kKeep) ? this.avatarUrl : avatarUrl as String?,
    ...
  );
}
```

---

### BUG 4 — HIGH | `wardrobe_provider.dart` `addItem` — no error handling; a failed upload leaves an orphaned Storage object and throws an unhandled exception to the caller

**File:** `lib/presentation/providers/wardrobe_provider.dart`, lines 38–52

`addItem` has no try/catch. If `repo.addItem` throws at any point after the
Storage upload succeeds but before the DB insert returns (network blip, RLS
rejection), the provider's `state` is never updated, so the UI sees no change —
but the bytes are already uploaded. On the next attempt Supabase Storage will
accept an upsert to the same path (since the UUID is regenerated), so a new
orphaned object accumulates. More importantly, the unhandled exception propagates
to the UI without restoring `state`, leaving the provider in whatever
`AsyncLoading`-adjacent state `addItem` entered.

The consistent pattern used by `updateItem` and `deleteItem` — saving `previous`,
catching, restoring — is missing here.

**Fix:**

```dart
Future<WardrobeItem> addItem(Uint8List imageBytes) async {
  final previous = state;
  try {
    final repo = ref.read(wardrobeRepositoryProvider);
    _currentStep = 'Starting…';
    final item = await repo.addItem(
      profileId: arg,
      imageBytes: imageBytes,
      onStep: (step) => _currentStep = step,
    );
    state = AsyncData<List<WardrobeItem>>([item, ...(state.value ?? <WardrobeItem>[])]);
    return item;
  } catch (e, st) {
    state = AsyncError<List<WardrobeItem>>(e, st);
    await Future.delayed(Duration.zero);
    state = previous;
    rethrow;
  }
}
```

---

### BUG 5 — HIGH | `calendar_repository.dart` `updateEvent` — sends `created_at` to Postgres UPDATE (same root as Bug 1, but additionally can silently break RLS if the DB rejects it)

Already documented in Bug 1. Flagged separately because the `createEvent` method
correctly strips `created_at` (line 42), making the omission in `updateEvent` look
intentional and easy to miss in a future diff.

---

### BUG 6 — MEDIUM | `calendar_event.dart` `fromJson` — `eventDate` is hardcoded to UTC midnight, causing off-by-one day errors for users west of UTC

**File:** `lib/data/models/calendar_event.dart`, line 35

```dart
eventDate: DateTime.parse('${json['event_date']}T00:00:00Z'),
```

Appending `Z` interprets the DATE string as UTC midnight. When `eventsForDay`
(calendar_provider.dart line 78–83) compares `e.eventDate.year/month/day` against
a local `DateTime`, a user in UTC-5 will see Monday's event appear on Sunday
(since UTC midnight on Monday is still Sunday locally).

`calendarEventsMapProvider` builds map keys as
`DateTime(year, month, day)` which is local time — so the key and the stored date
are in different time zones, causing events to appear on the wrong day in
`TableCalendar`.

**Fix:** Parse as local midnight instead:

```dart
eventDate: DateTime(
  int.parse('${json['event_date']}'.substring(0, 4)),
  int.parse('${json['event_date']}'.substring(5, 7)),
  int.parse('${json['event_date']}'.substring(8, 10)),
),
// Or more concisely:
eventDate: DateFormat('yyyy-MM-dd').parse(json['event_date'] as String), // intl package
```

---

### BUG 7 — MEDIUM | `wardrobe_provider.dart` `_currentStep` mutation is not observable — UI polling it will never trigger a rebuild

**File:** `lib/presentation/providers/wardrobe_provider.dart`, lines 35–36

`_currentStep` is a plain Dart field on the `WardrobeNotifier`. Riverpod only
notifies listeners when `state` changes. Any widget reading `ref.read(wardrobeProvider(id).notifier).currentStep` will get a snapshot at read time, but
assigning `_currentStep = step` inside the async pipeline never triggers a
rebuild. The progress label shown in the UI is effectively frozen at whatever
value it had when the widget last built.

**Fix:** Use a separate `StateProvider` or a `ValueNotifier` for step progress,
and update it so watchers are notified:

```dart
// Option A: separate provider the UI can watch
final addItemStepProvider = StateProvider.autoDispose.family<String, String>(
  (ref, profileId) => '',
);

// In WardrobeNotifier.addItem, instead of _currentStep = step:
ref.read(addItemStepProvider(arg).notifier).state = step;
```

---

## Verdict
NEEDS CHANGES — two critical bugs (orphaned data / guaranteed runtime errors on updates), two high severity bugs (unhandled exceptions, data loss on copyWith), and two medium bugs that cause wrong-day display and broken UI feedback.
