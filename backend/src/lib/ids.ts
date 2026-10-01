import { createHash, randomUUID } from 'node:crypto';

/// Namespace for Proviyaa POS name-based ids. Fixed forever: changing it
/// would re-key every synced record.
const POS_NAMESPACE = '6f1c2b8e-3d4a-5e6f-8a9b-0c1d2e3f4a5b';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const isUuid = (s: unknown): s is string => typeof s === 'string' && UUID_RE.test(s);

export const newId = (): string => randomUUID();

/// RFC 4122 version-5 (SHA-1, name-based) UUID.
export function uuidv5(name: string, namespace = POS_NAMESPACE): string {
  const ns = Buffer.from(namespace.replace(/-/g, ''), 'hex');
  const hash = createHash('sha1').update(ns).update(name, 'utf8').digest();
  const b = hash.subarray(0, 16);
  b[6] = (b[6]! & 0x0f) | 0x50;
  b[8] = (b[8]! & 0x3f) | 0x80;
  const h = b.toString('hex');
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
}

/// The central id for a device record. Device keys ("ORD-9981", "T1",
/// "dish_sb_01") aren't UUIDs and repeat across organizations and branches,
/// so the central id is derived from (organization, branch-or-org, entity,
/// device key): the same record always maps to the same row, which makes
/// every push an idempotent upsert. A key that already is a UUID (a record
/// that came from the central database in the first place) is used as-is.
export function stableId(
  organizationId: string,
  locationScope: string | null,
  entity: string,
  deviceKey: string,
): string {
  if (isUuid(deviceKey)) return deviceKey.toLowerCase();
  return uuidv5(`${organizationId}|${locationScope ?? '*'}|${entity}|${deviceKey}`);
}

export function sha256(value: string): string {
  return createHash('sha256').update(value, 'utf8').digest('hex');
}

/// Deterministic JSON (sorted keys) for hashing payloads.
export function canonicalJson(v: unknown): string {
  if (v === null || typeof v !== 'object') return JSON.stringify(v);
  if (Array.isArray(v)) return `[${v.map(canonicalJson).join(',')}]`;
  const o = v as Record<string, unknown>;
  return `{${Object.keys(o)
    .sort()
    .map((k) => `${JSON.stringify(k)}:${canonicalJson(o[k])}`)
    .join(',')}}`;
}
