import { decodeBytea, type Row } from '../../db/types.js';
import { unprocessable } from '../../lib/errors.js';
import type { ContractColumn, ContractTable } from '../../schema/contract.js';
import type { DeviceRow } from './types.js';

/// Validates and normalizes an incoming device row against the contract:
/// every column present with the right type, defaults applied, unknown
/// keys dropped. Returns wire-form values (ISO timestamps, base64 blobs
/// decoded to bytes).
export function coerceDeviceRow(table: ContractTable, input: DeviceRow, keyOnly = false): Row {
  const out: Row = {};
  const columns = keyOnly ? table.columns.filter((c) => table.primary_key.includes(c.name)) : table.columns;
  for (const c of columns) {
    const has = Object.prototype.hasOwnProperty.call(input, c.name);
    let v = has ? input[c.name] : undefined;
    if (v === undefined || v === null) {
      if (!has && c.default) v = 'now' in c.default ? new Date().toISOString() : c.default.value;
      else v = null;
      if (v === null) {
        if (!c.nullable) throw unprocessable(`${table.resource}.${c.name} is required.`);
        out[c.name] = null;
        continue;
      }
    }
    out[c.name] = coerceValue(table, c, v);
  }
  return out;
}

function coerceValue(table: ContractTable, c: ContractColumn, v: unknown): unknown {
  const bad = () => unprocessable(`${table.resource}.${c.name} must be ${c.type}.`);
  switch (c.type) {
    case 'text':
      if (typeof v !== 'string') throw bad();
      return v;
    case 'int':
      if (typeof v !== 'number' || !Number.isInteger(v)) throw bad();
      return v;
    case 'real':
      if (typeof v !== 'number' || !Number.isFinite(v)) throw bad();
      return v;
    case 'bool':
      if (typeof v !== 'boolean') throw bad();
      return v;
    case 'timestamp': {
      const d = typeof v === 'string' || typeof v === 'number' ? new Date(v) : null;
      if (!d || Number.isNaN(d.getTime())) throw bad();
      return d.toISOString();
    }
    case 'blob':
      if (typeof v !== 'string') throw bad();
      return new Uint8Array(Buffer.from(v, 'base64'));
  }
}

/// Central value → wire value for the device, by contract column type.
export function toWireValue(c: ContractColumn, v: unknown): unknown {
  if (v === null || v === undefined) return null;
  switch (c.type) {
    case 'int':
      return Math.round(Number(v));
    case 'real':
      return Number(v);
    case 'bool':
      return Boolean(v);
    case 'timestamp':
      return new Date(v as string).toISOString();
    case 'blob': {
      const bytes = decodeBytea(v);
      return bytes ? Buffer.from(bytes).toString('base64') : null;
    }
    default:
      return String(v);
  }
}

export function deviceKey(table: ContractTable, row: Row): string {
  return table.primary_key.map((c) => String(row[c])).join('|');
}

export function keyColumns(table: ContractTable, row: Row): Row {
  const out: Row = {};
  for (const c of table.primary_key) out[c] = row[c];
  return out;
}
