import { useEffect, useRef, useState, type ReactNode } from "react";
import { getKeycloak } from "./keycloak";
import { AuthContext } from "./AuthContext";

export function AuthProvider({ children }: { children: ReactNode }) {
  const [authenticated, setAuthenticated] = useState(false);
  const [loading, setLoading] = useState(true);
  const initCalled = useRef(false);

  useEffect(() => {
    if (initCalled.current) return;
    initCalled.current = true;

    const keycloak = getKeycloak();
    keycloak
      .init({ onLoad: "check-sso", pkceMethod: "S256" })
      .then((auth) => {
        setAuthenticated(auth);
        setLoading(false);
      })
      .catch((err) => {
        console.error("Keycloak init failed", err);
        setLoading(false);
      });
  }, []);

  const login = () => getKeycloak().login();
  const logout = () => getKeycloak().logout({ redirectUri: window.location.origin });

  const keycloak = getKeycloak();
  return (
    <AuthContext.Provider
      value={{
        authenticated,
        username: keycloak.tokenParsed?.preferred_username,
        token: keycloak.token,
        login,
        logout,
        loading,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}
