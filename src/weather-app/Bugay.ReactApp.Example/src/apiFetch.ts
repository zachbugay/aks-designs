import { getKeycloak } from "./keycloak";
import { getConfig } from "./config";

export async function apiFetch(
  path: string,
  init?: RequestInit,
): Promise<Response> {

  const keycloak = getKeycloak();
  const { apiBaseUrl } = getConfig();
    
  if (!keycloak.authenticated) {
    throw new Error("Not authenticated,  please log in first.");
  }

  try {
    await keycloak.updateToken(30);
  } catch {
    keycloak.login();
    throw new Error("Session expired,  redirecting to login.");
  }

  return fetch(`${apiBaseUrl}${path}`, {
    ...init,
    headers: {
      ...init?.headers,
      Authorization: `Bearer ${keycloak.token}`,
    },
  });
}
