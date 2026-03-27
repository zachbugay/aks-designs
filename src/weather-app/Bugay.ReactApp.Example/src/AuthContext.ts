import { createContext } from "react";

export interface AuthContextType {
  authenticated: boolean;
  username: string | undefined;
  token: string | undefined;
  login: () => void;
  logout: () => void;
  loading: boolean;
}

export const AuthContext = createContext<AuthContextType | null>(null);
