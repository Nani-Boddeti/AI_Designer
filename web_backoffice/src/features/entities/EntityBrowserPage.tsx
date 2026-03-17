import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { getEntity } from './EntityConfig';
import { listInstances, updateInstance, deleteInstance } from './entity_api';

function truncate(value: unknown): string {
  if (value === null || value === undefined) return '—';
  const str = String(value);
  if (str.length > 8 && /^[0-9a-f-]{36}$/i.test(str)) {
    return str.slice(0, 8) + '…';
  }
  return str;
}

function displayCell(value: unknown): string {
  if (value === null || value === undefined) return '—';
  if (typeof value === 'boolean') return value ? 'Yes' : 'No';
  return truncate(value);
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Row = Record<string, any>;

export function EntityBrowserPage() {
  const { entityKey } = useParams<{ entityKey: string }>();
  const entity = getEntity(entityKey ?? '');

  const [rows, setRows] = useState<Row[]>([]);
  const [loading, setLoading] = useState(false);
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState<Row | null>(null);
  const [draft, setDraft] = useState<Record<string, unknown>>({});
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  useEffect(() => {
    setSelected(null);
    setSearch('');
    setRows([]);
  }, [entityKey]);

  useEffect(() => {
    if (!entity) return;
    const timer = setTimeout(() => {
      setLoading(true);
      setError(null);
      listInstances(entity, search)
        .then(setRows)
        .catch((e: unknown) => setError(e instanceof Error ? e.message : String(e)))
        .finally(() => setLoading(false));
    }, 300);
    return () => clearTimeout(timer);
  }, [entity, search]);

  if (!entity) {
    return (
      <div className="panel" style={{ padding: 24 }}>
        <p style={{ color: 'var(--danger)' }}>Unknown entity: {entityKey}</p>
      </div>
    );
  }

  const handleRowClick = (row: Row) => {
    setSelected(row);
    setDraft({ ...row });
    setError(null);
    setSuccess(null);
  };

  const handleDraftChange = (key: string, value: unknown) => {
    setDraft((prev) => ({ ...prev, [key]: value }));
  };

  const handleSave = async () => {
    if (!selected) return;
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const patch: Record<string, unknown> = {};
      for (const field of entity.fields) {
        if (field.editable) {
          patch[field.key] = draft[field.key] ?? null;
        }
      }
      await updateInstance(entity, String(selected.id), patch);
      setSuccess('Saved successfully.');
      setLoading(true);
      const refreshed = await listInstances(entity, search);
      setRows(refreshed);
      const updated = refreshed.find((r) => r.id === selected.id) ?? selected;
      setSelected(updated);
      setDraft({ ...updated });
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setSaving(false);
      setLoading(false);
    }
  };

  const handleDelete = async () => {
    if (!selected) return;
    if (!confirm(`Delete this ${entity.label} record? This cannot be undone.`)) return;
    setError(null);
    setSuccess(null);
    try {
      await deleteInstance(entity, String(selected.id));
      setSelected(null);
      setDraft({});
      const refreshed = await listInstances(entity, search);
      setRows(refreshed);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : String(e));
    }
  };

  return (
    <div className="entity-browser">
      {/* Search row */}
      <div className="browser-top">
        <h2 className="entity-title">{entity.label}</h2>
        <input
          className="text-input browser-search"
          placeholder="Search…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      {/* List */}
      <div className="panel browser-list">
        <table className="grid">
          <thead>
            <tr>
              {entity.listColumns.map((col) => (
                <th key={col}>{col}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {loading && (
              <tr className="loading-row">
                <td colSpan={entity.listColumns.length}>Loading…</td>
              </tr>
            )}
            {!loading && rows.length === 0 && (
              <tr className="loading-row">
                <td colSpan={entity.listColumns.length}>No records found.</td>
              </tr>
            )}
            {!loading &&
              rows.map((row, i) => (
                <tr
                  key={i}
                  onClick={() => handleRowClick(row)}
                  className={selected === row || selected?.id === row.id ? 'selected-row' : ''}
                >
                  {entity.listColumns.map((col) => (
                    <td key={col}>
                      <span className="cell-trunc" title={String(row[col] ?? '')}>
                        {displayCell(row[col])}
                      </span>
                    </td>
                  ))}
                </tr>
              ))}
          </tbody>
        </table>
      </div>

      {/* Editor */}
      {selected ? (
        <div className="panel browser-editor">
          <div className="editor-header">
            <strong>Editing: {entity.label}</strong>
            <code className="editor-id">{selected.id}</code>
          </div>
          <div className="entity-form-grid">
            {entity.fields.map((field) => {
              const val = draft[field.key];

              if (!field.editable || field.type === 'readonly') {
                return (
                  <div key={field.key} className="readonly-field">
                    <span>{field.label}</span>
                    <strong>{val === null || val === undefined ? '—' : String(val)}</strong>
                  </div>
                );
              }

              if (field.type === 'boolean') {
                return (
                  <label key={field.key} className="entity-checkbox">
                    <input
                      type="checkbox"
                      checked={Boolean(val)}
                      onChange={(e) => handleDraftChange(field.key, e.target.checked)}
                    />
                    {field.label}
                  </label>
                );
              }

              if (field.type === 'select') {
                return (
                  <label key={field.key} className="form-label">
                    {field.label}
                    <select
                      className="text-input"
                      value={String(val ?? '')}
                      onChange={(e) => handleDraftChange(field.key, e.target.value)}
                    >
                      <option value="">— select —</option>
                      {field.options?.map((opt) => (
                        <option key={opt} value={opt}>
                          {opt}
                        </option>
                      ))}
                    </select>
                  </label>
                );
              }

              if (field.type === 'datetime') {
                const dtVal = val ? String(val).slice(0, 16) : '';
                return (
                  <label key={field.key} className="form-label">
                    {field.label}
                    <input
                      className="text-input"
                      type="datetime-local"
                      value={dtVal}
                      onChange={(e) =>
                        handleDraftChange(field.key, e.target.value ? e.target.value + ':00Z' : null)
                      }
                    />
                  </label>
                );
              }

              if (field.type === 'date') {
                return (
                  <label key={field.key} className="form-label">
                    {field.label}
                    <input
                      className="text-input"
                      type="date"
                      value={String(val ?? '')}
                      onChange={(e) => handleDraftChange(field.key, e.target.value || null)}
                    />
                  </label>
                );
              }

              if (field.type === 'number') {
                return (
                  <label key={field.key} className="form-label">
                    {field.label}
                    <input
                      className="text-input"
                      type="number"
                      value={val === null || val === undefined ? '' : String(val)}
                      onChange={(e) =>
                        handleDraftChange(field.key, e.target.value ? Number(e.target.value) : null)
                      }
                    />
                  </label>
                );
              }

              // text (default)
              return (
                <label key={field.key} className="form-label">
                  {field.label}
                  <input
                    className="text-input"
                    type="text"
                    value={String(val ?? '')}
                    onChange={(e) => handleDraftChange(field.key, e.target.value)}
                  />
                </label>
              );
            })}
          </div>

          {!entity.readOnly && (
            <div className="actions-row">
              <button className="btn-success" onClick={handleSave} disabled={saving}>
                {saving ? 'Saving…' : 'Save'}
              </button>
              <button className="btn-danger" onClick={handleDelete}>
                Delete
              </button>
              <button onClick={() => setSelected(null)}>Cancel</button>
            </div>
          )}

          {error && (
            <p className="status-line" style={{ color: 'var(--danger)' }}>
              {error}
            </p>
          )}
          {success && (
            <p className="status-line" style={{ color: 'var(--accent)' }}>
              {success}
            </p>
          )}
        </div>
      ) : (
        <div
          className="panel browser-editor"
          style={{ color: 'var(--muted)', textAlign: 'center', padding: '32px' }}
        >
          Select a row to edit
        </div>
      )}
    </div>
  );
}
