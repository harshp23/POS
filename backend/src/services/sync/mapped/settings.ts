import type { RequestContext } from '../../../context.js';
import { eq, type Row } from '../../../db/types.js';
import { stableId } from '../../../lib/ids.js';
import { unprocessable } from '../../../lib/errors.js';
import { contractTable } from '../../../schema/contract.js';
import { coerceDeviceRow } from '../device-rows.js';
import { loadExtras, saveExtra } from '../extras.js';
import { centralId, type SyncSession } from '../session.js';
import type { DeviceRow, PullPage, SyncAdapter, WriteOutcome } from '../types.js';

const STATIONS_KEY = 'kds_kitchen_stations';
const ALERTS_KEY = 'kds_alert_settings';
const STATION = 'kitchen_station';
const SETTING = 'setting';

interface DeviceStation {
  name: string;
  targetMinutes?: number;
  colorValue?: number;
  active?: boolean;
}

const stationKey = (name: string) =>
  name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '') || 'main';

const hexColour = (argb: number | undefined) => `#${((argb ?? 0xff76ec00) & 0xffffff).toString(16).padStart(6, '0')}`;
const argbFromHex = (hex: string) => (0xff000000 | Number.parseInt(hex.replace('#', ''), 16)) >>> 0;

/// app_metadata settings rows. "kds_kitchen_stations" (a JSON list on the
/// device) ↔ public.kitchen_stations rows, chain-wide; the SLA minutes and
/// active flag the OS table has no column for sit in pos_entity_extras.
/// "kds_alert_settings" is a per-branch preference kept in extras only.
export class SettingsAdapter implements SyncAdapter {
  readonly resource = 'settings';
  readonly module = 'operations' as const;
  private readonly t = contractTable(this.resource);

  async upsert(ctx: RequestContext, _s: SyncSession, input: DeviceRow): Promise<WriteOutcome> {
    const row = coerceDeviceRow(this.t, input);
    const key = String(row.key);
    if (key === ALERTS_KEY) {
      const id = centralId(ctx, 'location', SETTING, key);
      await saveExtra(ctx, SETTING, id, key, { value: row.value });
      return { server_id: id, version: null };
    }
    if (key !== STATIONS_KEY) throw unprocessable(`Setting "${key}" is not synced.`);

    let list: DeviceStation[];
    try {
      list = JSON.parse(String(row.value));
      if (!Array.isArray(list)) throw new Error();
    } catch {
      throw unprocessable('kds_kitchen_stations must be a JSON list of stations.');
    }
    const org = ctx.m.organization_id;
    const existing = await ctx.db.select<Row>('kitchen_stations', { filters: [eq('organization_id', org)] });
    const idByKey = new Map(existing.map((s) => [s.key as string, s.id as string]));
    const kept = new Set<string>();
    for (const [i, st] of list.entries()) {
      const skey = stationKey(st.name);
      const id = idByKey.get(skey) ?? stableId(org, null, STATION, skey);
      kept.add(id);
      const saved = await ctx.db.upsert(
        'kitchen_stations',
        [{ id, organization_id: org, key: skey, name: st.name.trim(), colour: hexColour(st.colorValue), sort_order: i }],
        ['id'],
        'organization_id',
      );
      if (!saved.length) throw unprocessable('A kitchen station id clashes with another organization.');
      await saveExtra(ctx, STATION, id, skey, {
        target_minutes: st.targetMinutes ?? 15,
        color_value: st.colorValue ?? null,
        active: st.active ?? true,
        removed: false,
      });
    }
    // Members can't delete OS kitchen stations; one dropped from the list is
    // flagged removed instead and left out of every device's list.
    for (const s of existing) {
      if (!kept.has(s.id as string)) await saveExtra(ctx, STATION, s.id as string, s.key as string, { removed: true, active: false });
    }
    return { server_id: centralId(ctx, 'location', SETTING, key), version: null };
  }

  async remove(): Promise<WriteOutcome | null> {
    return null;
  }

  async pull(ctx: RequestContext): Promise<PullPage> {
    const rows: DeviceRow[] = [];
    const stations = await ctx.db.select<Row>('kitchen_stations', {
      filters: [eq('organization_id', ctx.m.organization_id)],
      order: [{ col: 'sort_order' }, { col: 'name' }],
    });
    if (stations.length) {
      const extras = await loadExtras(ctx, STATION, stations.map((s) => s.id as string));
      const list = stations
        .filter((s) => !extras.get(s.id as string)?.data.removed)
        .map((s) => {
          const d = extras.get(s.id as string)?.data ?? {};
          return {
            name: s.name as string,
            targetMinutes: (d.target_minutes as number) ?? 15,
            colorValue: (d.color_value as number) ?? argbFromHex(String(s.colour)),
            active: (d.active as boolean) ?? true,
          };
        });
      if (list.length) rows.push({ key: STATIONS_KEY, value: JSON.stringify(list) });
    }
    const alertsId = centralId(ctx, 'location', SETTING, ALERTS_KEY);
    const alerts = (await loadExtras(ctx, SETTING, [alertsId])).get(alertsId);
    if (alerts?.data.value) rows.push({ key: ALERTS_KEY, value: alerts.data.value });
    return { rows, deleted: [], snapshot: false, cursor: null, versions: {}, more: false };
  }
}
