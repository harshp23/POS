export interface AuthUser {
  id: string;
  email: string;
}

export interface AuthSession {
  access_token: string;
  /// The same token: master-admin tokens are single, sliding JWTs;
  /// /v1/auth/refresh exchanges a still-valid one for a fresh one.
  refresh_token: string;
  /// Epoch seconds.
  expires_at: number;
  user: AuthUser;
}

/// Where a sign-in came from, for the login history.
export interface SignInMeta {
  ip?: string | null;
  userAgent?: string | null;
}

export interface AuthProvider {
  signIn(email: string, password: string, meta?: SignInMeta): Promise<AuthSession>;
  /// Changes the account's password after checking the current one, ends
  /// the account's other sessions and returns a fresh one for the caller.
  changePassword(userId: string, current: string, next: string): Promise<AuthSession>;
  /// Signs one token out: it is refused from now on.
  revoke(token: string): Promise<void>;
  refresh(token: string): Promise<AuthSession>;
  /// Validates an access token and returns its user; throws ApiError 401.
  verify(token: string): Promise<AuthUser>;
}
