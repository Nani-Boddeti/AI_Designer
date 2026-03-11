// household_membership_model_test.dart
// Unit tests for HouseholdMembership model: fromJson parsing and field mapping.
// Pure Dart — no Flutter, no Supabase.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_designer_assist/data/models/household_membership.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _validJson({
  String id = 'mem-1',
  String userId = 'user-uuid-1',
  String householdId = 'household-uuid-1',
  bool isAdmin = false,
  String joinedAt = '2024-03-01T10:00:00.000Z',
}) =>
    {
      'id': id,
      'user_id': userId,
      'household_id': householdId,
      'is_admin': isAdmin,
      'joined_at': joinedAt,
    };

void main() {
  group('HouseholdMembership.fromJson — field mapping', () {
    test('parses all fields correctly for non-admin member', () {
      final m = HouseholdMembership.fromJson(_validJson());
      expect(m.id, 'mem-1');
      expect(m.userId, 'user-uuid-1');
      expect(m.householdId, 'household-uuid-1');
      expect(m.isAdmin, isFalse);
      expect(m.joinedAt, DateTime.parse('2024-03-01T10:00:00.000Z'));
    });

    test('parses is_admin = true for admin member', () {
      final m = HouseholdMembership.fromJson(_validJson(isAdmin: true));
      expect(m.isAdmin, isTrue);
    });

    test('parses UUID-style id fields without error', () {
      final m = HouseholdMembership.fromJson(_validJson(
        id: '550e8400-e29b-41d4-a716-446655440000',
        userId: 'auth-user-uuid-abc',
        householdId: 'house-hold-uuid-xyz',
      ));
      expect(m.id, '550e8400-e29b-41d4-a716-446655440000');
      expect(m.userId, 'auth-user-uuid-abc');
      expect(m.householdId, 'house-hold-uuid-xyz');
    });

    test('joinedAt parses ISO-8601 timestamp correctly', () {
      final m = HouseholdMembership.fromJson(
        _validJson(joinedAt: '2025-01-15T08:30:00.000Z'),
      );
      expect(m.joinedAt.year, 2025);
      expect(m.joinedAt.month, 1);
      expect(m.joinedAt.day, 15);
    });

    test('joinedAt with timezone offset parses without error', () {
      final m = HouseholdMembership.fromJson(
        _validJson(joinedAt: '2024-06-01T12:00:00+05:30'),
      );
      expect(m.joinedAt, isNotNull);
    });
  });

  group('HouseholdMembership — admin vs member distinction', () {
    test('two memberships same household: one admin, one not', () {
      final admin = HouseholdMembership.fromJson(_validJson(
        id: 'mem-admin',
        userId: 'user-1',
        isAdmin: true,
        joinedAt: '2024-01-01T00:00:00.000Z',
      ));
      final member = HouseholdMembership.fromJson(_validJson(
        id: 'mem-member',
        userId: 'user-2',
        isAdmin: false,
        joinedAt: '2024-02-01T00:00:00.000Z',
      ));
      expect(admin.isAdmin, isTrue);
      expect(member.isAdmin, isFalse);
      expect(admin.householdId, member.householdId); // same household
    });

    test('admin joined before member (joined_at ordering)', () {
      final admin = HouseholdMembership.fromJson(_validJson(
        id: 'mem-1',
        userId: 'user-1',
        isAdmin: true,
        joinedAt: '2024-01-01T00:00:00.000Z',
      ));
      final member = HouseholdMembership.fromJson(_validJson(
        id: 'mem-2',
        userId: 'user-2',
        isAdmin: false,
        joinedAt: '2024-06-01T00:00:00.000Z',
      ));
      expect(admin.joinedAt.isBefore(member.joinedAt), isTrue);
    });
  });

  group('HouseholdMembership — auto-promote scenario', () {
    // Simulates the leave-household Edge Function logic:
    // When the only admin leaves, the longest-tenured other member is promoted.
    test('longest-tenured member is the one with earliest joinedAt', () {
      final members = [
        HouseholdMembership.fromJson(_validJson(
          id: 'mem-3', userId: 'user-3', isAdmin: false,
          joinedAt: '2024-05-01T00:00:00.000Z',
        )),
        HouseholdMembership.fromJson(_validJson(
          id: 'mem-2', userId: 'user-2', isAdmin: false,
          joinedAt: '2024-03-01T00:00:00.000Z',
        )),
        HouseholdMembership.fromJson(_validJson(
          id: 'mem-4', userId: 'user-4', isAdmin: false,
          joinedAt: '2024-07-01T00:00:00.000Z',
        )),
      ];
      final longestTenured = members
          .reduce((a, b) => a.joinedAt.isBefore(b.joinedAt) ? a : b);
      expect(longestTenured.userId, 'user-2');
    });

    test('sole member list after filtering out leaving user is empty', () {
      final allMembers = [
        HouseholdMembership.fromJson(_validJson(
          id: 'mem-1', userId: 'leaving-user', isAdmin: true,
          joinedAt: '2024-01-01T00:00:00.000Z',
        )),
      ];
      final others = allMembers.where((m) => m.userId != 'leaving-user').toList();
      expect(others, isEmpty);
    });
  });
}
