import { MasterAdminAuth } from './auth/master-admin.js';
import type { AuthProvider } from './auth/types.js';
import type { Db } from './db/types.js';

/// What the HTTP layer needs: the database and the identity provider.
export interface Platform {
  db: Db;
  auth: AuthProvider;
  close(): Promise<void>;
}

export function createPlatform(db: Db & { close?: () => Promise<void> }, jwtSecret: string, jwtExpiresIn = '7d'): Platform {
  return {
    db,
    auth: new MasterAdminAuth(db, jwtSecret, jwtExpiresIn),
    close: async () => db.close?.(),
  };
}
