import { readFileSync } from 'node:fs';

/// The device contract: every device table the backend keeps centrally,
/// generated from the app's Drift schema by
/// test/backend_schema_contract_test.dart (see lib/data/sync/sync_contract.dart).

export type ColumnType = 'text' | 'int' | 'real' | 'bool' | 'timestamp' | 'blob';

export interface ContractColumn {
  name: string;
  type: ColumnType;
  nullable: boolean;
  default: { value: unknown } | { now: true } | null;
}

export interface ContractTable {
  local_table: string;
  module: 'master' | 'operations';
  resource: string;
  primary_key: string[];
  unique_keys: string[][];
  auto_increment: string | null;
  only_keys: string[] | null;
  columns: ContractColumn[];
}

export interface Contract {
  contract_version: number;
  drift_schema_version: number;
  tables: ContractTable[];
}

export const contract: Contract = JSON.parse(
  readFileSync(new URL('./pos-schema.json', import.meta.url), 'utf8'),
);

export function contractTable(resource: string): ContractTable {
  const t = contract.tables.find((x) => x.resource === resource);
  if (!t) throw new Error(`Unknown sync resource "${resource}"`);
  return t;
}
