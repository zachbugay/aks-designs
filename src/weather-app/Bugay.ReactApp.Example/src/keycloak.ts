import Keycloak from "keycloak-js";
import { getConfig } from "./config";

let keycloak: Keycloak | null = null;

export function initKeycloak(): Keycloak {
  if (keycloak) return keycloak;

  const config = getConfig();
  keycloak = new Keycloak({
    url: config.keycloakUrl,
    realm: config.keycloakRealm,
    clientId: config.keycloakClientId,
  });

  return keycloak;
}

export function getKeycloak(): Keycloak {
  if (!keycloak) {
    throw new Error("Keycloak not initialized. Call initKeycloak() first.");
  }
  return keycloak;
}
