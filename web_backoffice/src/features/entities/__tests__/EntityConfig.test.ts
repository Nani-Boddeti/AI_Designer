import { describe, it, expect } from 'vitest';
import { ENTITIES, getEntity } from '../EntityConfig';

describe('ENTITIES integrity', () => {
  it('every entity has required shape', () => {
    for (const e of ENTITIES) {
      expect(e.key, `${e.key}: missing key`).toBeTruthy();
      expect(e.label, `${e.key}: missing label`).toBeTruthy();
      expect(e.table, `${e.key}: missing table`).toBeTruthy();
      expect(e.fields.length, `${e.key}: no fields`).toBeGreaterThan(0);
      expect(e.listColumns.length, `${e.key}: no listColumns`).toBeGreaterThan(0);
      expect(e.searchColumn, `${e.key}: missing searchColumn`).toBeTruthy();
      expect(e.orderBy, `${e.key}: missing orderBy`).toBeTruthy();
    }
  });

  it('listColumns reference valid field keys', () => {
    for (const e of ENTITIES) {
      const fieldKeys = e.fields.map((f) => f.key);
      for (const col of e.listColumns) {
        expect(fieldKeys, `${e.key}: listColumn "${col}" not in fields`).toContain(col);
      }
    }
  });

  it('searchColumn references a valid field key', () => {
    for (const e of ENTITIES) {
      const fieldKeys = e.fields.map((f) => f.key);
      expect(fieldKeys, `${e.key}: searchColumn "${e.searchColumn}" not in fields`).toContain(
        e.searchColumn,
      );
    }
  });

  it('select fields declare options', () => {
    for (const e of ENTITIES) {
      for (const f of e.fields) {
        if (f.type === 'select') {
          expect(
            f.options?.length,
            `${e.key}.${f.key}: select field has no options`,
          ).toBeGreaterThan(0);
        }
      }
    }
  });

  it('readOnly entities have no editable fields', () => {
    const readOnlyEntities = ENTITIES.filter((e) => e.readOnly);
    expect(readOnlyEntities.length).toBeGreaterThan(0); // sanity: at least one exists
    for (const e of readOnlyEntities) {
      for (const f of e.fields) {
        expect(f.editable, `${e.key}.${f.key}: readOnly entity has editable field`).toBe(false);
      }
    }
  });

  it('known readOnly entities are marked readOnly', () => {
    const keys = ['usage', 'payment-transactions', 'device-tokens'];
    for (const key of keys) {
      expect(getEntity(key)?.readOnly, `${key} should be readOnly`).toBe(true);
    }
  });
});

describe('getEntity', () => {
  it('returns entity by key', () => {
    expect(getEntity('households')?.key).toBe('households');
    expect(getEntity('profiles')?.key).toBe('profiles');
  });

  it('returns undefined for unknown key', () => {
    expect(getEntity('nonexistent')).toBeUndefined();
  });
});
