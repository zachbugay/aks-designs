export interface AppConfig {
  keycloakUrl: string;
  keycloakRealm: string;
  keycloakClientId: string;
  apiBaseUrl: string;
}

let cached: AppConfig | null = null;

export async function loadConfig(): Promise<AppConfig> {
  if (cached) return cached;

  const response = await fetch("/config.json");
  if (!response.ok) {
    throw new Error(`Failed to load /config.json: ${response.status}`);
  }

  cached = (await response.json()) as AppConfig;
  return cached;
}

export function getConfig(): AppConfig {
  if (!cached) {
    throw new Error("Config not loaded. Call loadConfig() before getConfig().");
  }
  return cached;
}
