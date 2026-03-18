# Multi-Household Support — Technical Plan

**Model**: B — one active household at a time, switch via More screen
**Status**: Plan only — not yet implemented

---

## 1. DB Schema Changes

### New table: `household_memberships`

```sql
CREATE TABLE household_memberships (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  is_admin    BOOLEAN NOT NULL DEFAULT false,
  joined_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, household_id)
);

-- RLS
ALTER TABLE household_memberships ENABLE ROW LEVEL SECURITY;
CREATE POLICY "member sees own rows"
  ON household_memberships FOR SELECT
  USING (user_id = auth.uid());
CREATE POLICY "admin sees household rows"
  ON household_memberships FOR SELECT
  USING (
    household_id IN (
      SELECT household_id FROM household_memberships
      WHERE user_id = auth.uid() AND is_admin = true
    )
  );
```

### `profiles` table change

Add `active_household_id UUID REFERENCES households(id)` to track the user's currently active household (nullable — null before any household is joined/created).

```sql
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS active_household_id UUID REFERENCES households(id);
```

### Backfill existing data

```sql
-- Insert existing profile <-> household relationship into memberships table
INSERT INTO household_memberships (user_id, household_id, is_admin)
SELECT p.user_id, p.household_id, p.is_admin
FROM profiles p
WHERE p.household_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- Set active_household_id = existing household_id
UPDATE profiles SET active_household_id = household_id WHERE household_id IS NOT NULL;
```

---

## 2. Domain Model Changes

### `Profile` model

Add `activeHouseholdId: String?` field (replaces `householdId` as the "active" concept).
Keep `householdId` field as legacy / deprecate gradually.

### New `HouseholdMembership` model

```dart
class HouseholdMembership {
  final String id;
  final String userId;
  final String householdId;
  final bool isAdmin;
  final DateTime joinedAt;
}
```

### `AuthState`

```dart
class AuthState {
  final AppUser? user;
  final Profile? profile;
  final Household? household;         // active household
  final List<Household> allHouseholds; // all households the user belongs to
  // ...
}
```

---

## 3. Auth Provider Changes (`auth_provider.dart`)

### `_loadUserData`

After loading profile, also fetch all households the user belongs to via `household_memberships` JOIN `households`. Set `allHouseholds` in `AuthState`.

### `createHousehold`

1. INSERT household
2. INSERT into `household_memberships` (`is_admin: true`)
3. UPDATE `profiles.active_household_id`
4. Reload `AuthState` with new household + memberships

### `joinHousehold`

1. SELECT household by invite code
2. INSERT into `household_memberships` (`is_admin: false`)
3. UPDATE `profiles.active_household_id` to this household (set as active)
4. Reload `AuthState`

### New: `switchHousehold(String householdId)`

```dart
Future<void> switchHousehold(String householdId) async {
  final prev = state.value ?? const AuthState();
  state = AsyncData(prev.copyWith(isLoading: true));
  try {
    // 1. Update active_household_id in DB
    await supabase.from('profiles')
        .update({'active_household_id': householdId})
        .eq('id', prev.profile!.id);
    // 2. Load full household data
    final household = await _loadHousehold(householdId);
    // 3. Load members for new household
    state = AsyncData(AuthState(
      user: prev.user,
      profile: prev.profile!.copyWith(activeHouseholdId: householdId),
      household: household,
      allHouseholds: prev.allHouseholds,
    ));
    // 4. Invalidate wardrobe/outfit/calendar providers (clear stale data)
    ref.invalidate(wardrobeProvider);
    ref.invalidate(outfitProvider);
  } catch (e) {
    state = AsyncData(prev.copyWith(isLoading: false, error: e.toString()));
  }
}
```

### New: `leaveHousehold(String householdId)`

```dart
Future<void> leaveHousehold(String householdId) async {
  // 1. If user is only admin: auto-assign another member as admin (or disband if alone)
  //    SELECT members WHERE household_id = ? AND user_id != current
  //    If empty → DELETE household (CASCADE removes memberships)
  //    Else → UPDATE household_memberships SET is_admin=true WHERE user_id = members[0].userId
  // 2. DELETE FROM household_memberships WHERE user_id = current AND household_id = ?
  // 3. If active_household_id == householdId → set active to another household or null
  // 4. Reload AuthState
}
```

**Auto-admin rule**: When the only admin leaves and other members exist, promote the longest-tenured member (ORDER BY joined_at ASC LIMIT 1). Can be done via a Supabase Edge Function `leave-household` for atomicity.

---

## 4. Post-Login Household Picker

### When to show

Router check: after `authProvider` is loaded with `user != null`, if `allHouseholds.isEmpty` → redirect to `/onboarding` (create/join). If `allHouseholds.length > 1` AND `activeHouseholdId == null` → show `HouseholdPickerScreen`.

This is a one-time screen shown only when the active household is unset (e.g., new device, or after leaving a household).

### `HouseholdPickerScreen`

- Route: `/household-picker`
- Shows list of `allHouseholds` as selectable cards
- Tapping a card calls `authNotifier.switchHousehold(id)` then pushes to `/home`
- Also shows "Create new" and "Join with code" options at bottom

---

## 5. Router Changes (`app_router.dart`)

```dart
// In redirect logic, after auth check:
final authState = ref.read(authProvider).value;
if (authState?.user != null && authState?.household == null) {
  if (authState!.allHouseholds.isEmpty) return '/onboarding';
  return '/household-picker'; // has households but none active
}
```

Add route:
```dart
GoRoute(
  path: '/household-picker',
  builder: (_, __) => const HouseholdPickerScreen(),
),
```

---

## 6. Switch Household from More Screen

In `MoreScreen` (or settings), add a "Households" section:

```dart
// Show current active household name
// Show "Switch Household" → opens bottom sheet with list
// Each row: household name, member count, admin badge
// Tap → switchHousehold(id)
// "Add Household" → push /onboarding
```

`AdminBadge` visibility: use `HouseholdMembership.isAdmin` for the current user per household.

---

## 7. `Profile.isAdmin` Semantics Change

Currently `isAdmin` is a field on `Profile`. With multi-household, admin status is per-household (stored in `household_memberships.is_admin`).

**Migration**: `Profile.isAdmin` should read from the active household's membership row.
Keep `Profile.isAdmin` as a computed getter for the active household's membership.
Load the current user's membership row for the active household and surface it in `AuthState`.

---

## 8. Files to Create / Modify

| File | Change |
|------|--------|
| `lib/data/models/auth_state.dart` | Add `allHouseholds`, `activeHouseholdId` |
| `lib/data/models/household_membership.dart` | New model |
| `lib/presentation/providers/auth_provider.dart` | `switchHousehold`, `leaveHousehold`, `_loadMemberships` |
| `lib/presentation/screens/auth/household_picker_screen.dart` | New screen |
| `lib/presentation/screens/more/more_screen.dart` | Add "Households" section |
| `lib/router/app_router.dart` | Add `/household-picker` route + redirect logic |
| Supabase: `leave-household` Edge Function | Atomic leave + auto-admin-reassign |
| DB migrations | `household_memberships` table + `profiles.active_household_id` |

---

## 9. Edge Cases

- **User in 0 households**: show onboarding (create/join)
- **User in 1 household**: skip picker, auto-activate
- **Only admin leaving**: auto-promote longest-tenured member; if sole member, delete household
- **Deleting account**: cascade via `household_memberships` FK + trigger to auto-promote admins in remaining households
- **Stale wardrobe/outfit data**: invalidate `wardrobeProvider` / `outfitProvider` on household switch (all family scoped by `profile_id` which belongs to a household)
- **`currentProfileIdProvider`**: reset to `null` on household switch to prevent stale profile display

---

## 10. Implementation Order

1. DB migrations + RLS
2. `HouseholdMembership` model
3. `AuthState` + `AuthNotifier` changes (`createHousehold`, `joinHousehold`, `switchHousehold`, `leaveHousehold`)
4. Router changes + `HouseholdPickerScreen`
5. `MoreScreen` household switcher UI
6. `leave-household` Edge Function
7. Backfill existing data + test
