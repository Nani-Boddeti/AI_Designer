import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../../features/auth/AuthContext';
import { ENTITIES } from '../../features/entities/EntityConfig';

export function AppShell() {
  const { session, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  return (
    <div className="shell">
      <aside className="sidebar">
        <h1 className="logo">VibeVault Ops</h1>
        <p className="sidebar-email">{session?.user?.email}</p>
        <nav>
          {ENTITIES.map((e) => (
            <NavLink
              key={e.key}
              to={`/entities/${e.key}`}
              className={({ isActive }) => `nav-link${isActive ? ' nav-link--active' : ''}`}
            >
              {e.label}
              {e.readOnly && <span className="nav-badge">RO</span>}
            </NavLink>
          ))}
        </nav>
        <button className="btn-signout" onClick={handleLogout}>
          Sign Out
        </button>
      </aside>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
