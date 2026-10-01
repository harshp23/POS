/// Restaurant days run on the branch's clock (org_locations.time_zone,
/// India by default), not the server's or UTC: an order at 00:30 IST
/// belongs to that IST day even though it is still yesterday in UTC.
import type { RequestContext } from '../context.js';

export const DEFAULT_TIME_ZONE = 'Asia/Kolkata';

export const tzOf = (ctx: RequestContext): string => ctx.location?.time_zone || DEFAULT_TIME_ZONE;

/// YYYY-MM-DD of [d] in [tz].
export function localDate(tz: string, d = new Date()): string {
  try {
    return new Intl.DateTimeFormat('en-CA', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit' }).format(d);
  } catch {
    return localDate(DEFAULT_TIME_ZONE, d);
  }
}

/// HH:MM (24 h) of [d] in [tz].
export function localTime(tz: string, d = new Date()): string {
  try {
    return new Intl.DateTimeFormat('en-GB', { timeZone: tz, hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).format(d);
  } catch {
    return localTime(DEFAULT_TIME_ZONE, d);
  }
}

/// Minutes [tz] is ahead of UTC at [d].
export function tzOffsetMinutes(tz: string, d: Date): number {
  try {
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: tz,
      hourCycle: 'h23',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    }).formatToParts(d);
    const get = (t: string) => Number(parts.find((p) => p.type === t)?.value);
    const asUtc = Date.UTC(get('year'), get('month') - 1, get('day'), get('hour') % 24, get('minute'), get('second'));
    return Math.round((asUtc - (d.getTime() - d.getMilliseconds())) / 60_000);
  } catch {
    return 330;
  }
}

/// The instant a wall-clock time on [date] happens in [tz] (epoch ms).
export function localToEpoch(tz: string, date: string, hhmm = '00:00'): number {
  const guess = Date.parse(`${date}T${hhmm}:00Z`);
  const first = guess - tzOffsetMinutes(tz, new Date(guess)) * 60_000;
  // Re-check at the result: correct across a DST change.
  return guess - tzOffsetMinutes(tz, new Date(first)) * 60_000;
}
