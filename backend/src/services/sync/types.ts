import type { RequestContext } from '../../context.js';
import type { Row } from '../../db/types.js';
import { ApiError } from '../../lib/errors.js';
import type { SyncSession } from './session.js';

/// A device row in wire form: the Drift columns by SQL name, timestamps as
/// ISO-8601 strings, blobs as base64, bools as JSON booleans.
export type DeviceRow = Row;

export interface PushChange {
  /// Unique per device change (PRD §10 command id). Retrying the same id
  /// with the same payload returns the original result.
  change_id: string;
  resource: string;
  op: 'upsert' | 'delete';
  /// For upserts the full device row; for deletes just the key columns.
  row: DeviceRow;
  /// The server version the device last saw for this record, if any.
  base_version?: string | null;
}

export type PushStatus = 'accepted' | 'duplicate' | 'rejected' | 'conflict';

export interface PushResult {
  change_id: string;
  resource: string;
  status: PushStatus;
  server_id?: string;
  version?: string | null;
  error?: { code: string; message: string };
}

export interface PullPage {
  rows: DeviceRow[];
  /// Key columns of records deleted centrally since the cursor.
  deleted: DeviceRow[];
  /// true = rows is the complete set in scope; records the device got from
  /// the server earlier and doesn't see here were removed centrally.
  snapshot: boolean;
  cursor: string | null;
  /// Server version per record (keyed by the device key joined with "|").
  versions: Record<string, string>;
  more: boolean;
}

export interface WriteOutcome {
  server_id: string;
  version: string | null;
}

export interface SyncAdapter {
  resource: string;
  module: 'master' | 'operations';
  upsert(ctx: RequestContext, s: SyncSession, row: DeviceRow, baseVersion: string | null): Promise<WriteOutcome>;
  remove(ctx: RequestContext, s: SyncSession, key: DeviceRow): Promise<WriteOutcome | null>;
  pull(ctx: RequestContext, cursor: string | null): Promise<PullPage>;
}

/// The record changed centrally since the device last saw it.
export class SyncConflict extends ApiError {
  constructor(message: string, readonly current: Row | null) {
    super(409, 'sync_conflict', message);
  }
}

export const emptyPage = (): PullPage => ({ rows: [], deleted: [], snapshot: false, cursor: null, versions: {}, more: false });
