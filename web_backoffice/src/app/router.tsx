import { Navigate, Route, Routes, useLocation } from 'react-router-dom';
import { useAuth } from '../features/auth/AuthContext';
import { AppShell } from './layout/AppShell';
import { LoginPage } from '../features/auth/LoginPage';
import { EntityBrowserPage } from '../features/entities/EntityBrowserPage';

function ProtectedShell() {
  const { session, loading } = useAuth();
  const location = useLocation();

  if (loading) {
    return <div style={{ padding: 32, color: 'var(--muted)' }}>Loading…</div>;
  }
  if (!session) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }
  return <AppShell />;
}

export function AppRouter() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route element={<ProtectedShell />}>
        <Route path="/" element={<Navigate to="/entities/households" replace />} />
        <Route path="/entities/:entityKey" element={<EntityBrowserPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/entities/households" replace />} />
    </Routes>
  );
}
