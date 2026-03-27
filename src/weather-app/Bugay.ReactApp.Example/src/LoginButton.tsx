import { useAuth } from "./useAuth";

export default function LoginButton() {
  const { authenticated, username, login, logout, loading } = useAuth();

  if (loading) return <p>Loading…</p>;

  if (authenticated) {
    return (
      <div>
        <p>
          Signed in as <strong>{username}</strong>
        </p>
        <button onClick={logout}>Logout</button>
      </div>
    );
  }

  return <button onClick={login}>Login with Keycloak</button>;
}
