/// A fixed-window counter per key, in memory (one backend process). Used to
/// slow credential stuffing on sign-in; per-account lockout
/// (pos_login_security) is the durable second fence.
export class RateLimiter {
  private readonly hits = new Map<string, { count: number; resetAt: number }>();

  constructor(
    private readonly max: number,
    private readonly windowMs: number,
  ) {}

  /// Counts one attempt for [key]; returns the seconds to wait when over
  /// the limit, else 0.
  hit(key: string, now = Date.now()): number {
    if (this.hits.size > 10_000) this.sweep(now);
    const cur = this.hits.get(key);
    if (!cur || cur.resetAt <= now) {
      this.hits.set(key, { count: 1, resetAt: now + this.windowMs });
      return 0;
    }
    cur.count++;
    return cur.count > this.max ? Math.ceil((cur.resetAt - now) / 1000) : 0;
  }

  private sweep(now: number) {
    for (const [k, v] of this.hits) if (v.resetAt <= now) this.hits.delete(k);
  }
}
