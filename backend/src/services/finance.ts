import { Hono } from 'hono';
import { z } from 'zod';
import { requireCan, type RequestContext } from '../context.js';
import type { Row } from '../db/types.js';
import { ctxOf, intParam, readJson, type Env } from '../http.js';
import { conflict, notFound, unprocessable } from '../lib/errors.js';
import { isUuid } from '../lib/ids.js';
import { localDate, tzOf } from '../lib/time.js';
import { mountTableResource } from './crud.js';
import { audit, money, num, sectionGuard } from './section.js';

/// Finance (/v1/finance): money the restaurant can account for.
///
///   /dashboard   balances per account, today's figures, six-month cash flow
///   /payments    POS bills (payments) and online orders in one list
///   /entries     money in / out outside bills (cash register, owner top-ups
///                and withdrawals, capital, expenses) + approve / reject
///   /expense-heads · /expenses/summary
///   /settlements (+ /summary) · /documents (+ /summary)
///
/// Balances are what the panel knows about: POS collections by method plus
/// the entries recorded here. A branch manager sees their branch.

const PAID = `('paid', 'delivered')`;
/// Which account a POS payment method lands in.
const METHOD_ACCOUNT = `case p.method when 'cash' then 'cash' when 'upi' then 'upi' when 'wallet' then 'wallet' else 'bank' end`;

const branchParam = (ctx: RequestContext) => ctx.m.branch_scope;

function period(c: { req: { query: (k: string) => string | undefined } }, ctx: RequestContext) {
  const today = localDate(tzOf(ctx));
  const from = c.req.query('from') || today;
  const to = c.req.query('to') || today;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(from) || !/^\d{4}-\d{2}-\d{2}$/.test(to)) throw unprocessable('Dates must be YYYY-MM-DD.');
  if (to < from) throw unprocessable('"to" is before "from".');
  return { from, to, today, tz: tzOf(ctx) };
}

async function paymentRows(ctx: RequestContext, from: string, to: string, tz: string, source: string, limit: number): Promise<Row[]> {
  const pos =
    source === 'online'
      ? []
      : await ctx.db.query<Row>(
          `select p.id, p.created_at, 'pos' as source, coalesce(o.display_no::text, o.order_no::text) as reference, o.customer_name,
                  p.method, p.amount, p.reference as payment_ref,
                  case when o.status in ${PAID} then 'completed' when o.status = 'awaiting_payment' then 'pending_verification'
                       when o.status = 'cancelled' then 'cancelled' else 'open' end as status
             from payments p join orders o on o.id = p.order_id
            where p.organization_id = $1 and ($2::uuid is null or o.location_id = $2::uuid)
              and (p.created_at at time zone $5)::date between $3::date and $4::date
            order by p.created_at desc limit $6`,
          [ctx.m.organization_id, branchParam(ctx), from, to, tz, limit],
        );
  const online =
    source === 'pos' || ctx.m.branch_scope
      ? []
      : await ctx.db.query<Row>(
          `select id, created_at, 'online' as source, 'OL-' || upper(left(id::text, 8)) as reference,
                  coalesce(nullif(delivery_address ->> 'name', ''), 'Guest') as customer_name,
                  coalesce(payment_method, 'online') as method, total as amount, null as payment_ref,
                  case when status = 'cancelled' then 'cancelled'
                       when coalesce(payment_status, '') in ('paid', 'captured', 'success', 'completed') then 'completed'
                       else 'pending' end as status
             from ol_orders
            where organization_id = $1 and (created_at at time zone $4)::date between $2::date and $3::date
            order by created_at desc limit $5`,
          [ctx.m.organization_id, from, to, tz, limit],
        );
  return [...pos, ...online]
    .map((r): Row => ({ ...r, amount: money(r.amount) }))
    .sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)))
    .slice(0, limit);
}

const settlementSource = 'enum:zomato|swiggy|online_orders|pos_collections|upi|card|cash';

export function financeRoutes(): Hono<Env> {
  const app = new Hono<Env>();
  app.use('*', sectionGuard('finance'));

  app.get('/dashboard', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'finance', 'read');
    const { from, to, today, tz } = period(c, ctx);
    const org = ctx.m.organization_id;
    const branch = branchParam(ctx);

    const balances = await ctx.db.query<{ account: string; amount: string }>(
      `select account, sum(amount) as amount from (
         select ${METHOD_ACCOUNT} as account, p.amount
           from payments p join orders o on o.id = p.order_id
          where p.organization_id = $1 and o.status in ${PAID} and ($2::uuid is null or o.location_id = $2::uuid)
         union all
         select account, case when direction = 'in' then amount else -amount end
           from pos_finance_entries
          where organization_id = $1 and deleted_at is null and status = 'approved' and ($2::uuid is null or location_id = $2::uuid)
         union all
         select 'bank', amount from pos_settlements
          where organization_id = $1 and deleted_at is null and status = 'completed' and source in ('zomato', 'swiggy', 'online_orders')
            and ($2::uuid is null or location_id = $2::uuid)
       ) t group by account`,
      [org, branch],
    );
    const bal = (a: string) => money(balances.find((b) => b.account === a)?.amount);

    const [day] = await ctx.db.query<Row>(
      `select
         (select coalesce(sum(total), 0) from orders where organization_id = $1 and status in ${PAID}
            and ($2::uuid is null or location_id = $2::uuid) and (coalesce(paid_at, created_at) at time zone $4)::date = $3::date) as sales,
         (select coalesce(sum(p.amount), 0) from payments p join orders o on o.id = p.order_id
           where p.organization_id = $1 and o.status in ${PAID} and ($2::uuid is null or o.location_id = $2::uuid)
             and (p.created_at at time zone $4)::date = $3::date) as collection,
         (select coalesce(sum(amount), 0) from pos_finance_entries where organization_id = $1 and deleted_at is null
            and status = 'approved' and direction = 'out' and kind = 'expense' and entry_date = $3::date
            and ($2::uuid is null or location_id = $2::uuid)) as expense,
         (select coalesce(sum(amount), 0) from pos_settlements where organization_id = $1 and deleted_at is null and status = 'pending'
            and ($2::uuid is null or location_id = $2::uuid)) as pending_settlements,
         (select coalesce(sum(total), 0) from orders where organization_id = $1 and status = 'awaiting_payment'
            and ($2::uuid is null or location_id = $2::uuid)) as receivables`,
      [org, branch, today, tz],
    );
    const [payables] = await ctx.db.query<Row>(
      `select coalesce(sum(l.ordered_qty * l.unit_cost * (1 + coalesce(po.tax_pct, 0) / 100)), 0) as amount
         from pos_purchase_orders po
         join pos_purchase_order_lines l on l.organization_id = po.organization_id and l.po_number = po.number and l.deleted_at is null
        where po.organization_id = $1 and po.deleted_at is null and po.status in ('Pending', 'Approved', 'Partially Received')
          and ($2::uuid is null or po.location_id = $2::uuid)`,
      [org, branch],
    );

    const [flow] = await ctx.db.query<Row>(
      `select
         (select coalesce(sum(p.amount), 0) from payments p join orders o on o.id = p.order_id
           where p.organization_id = $1 and o.status in ${PAID} and ($2::uuid is null or o.location_id = $2::uuid)
             and (p.created_at at time zone $5)::date between $3::date and $4::date) as collections,
         (select coalesce(sum(amount) filter (where direction = 'in'), 0) from pos_finance_entries where organization_id = $1
            and deleted_at is null and status = 'approved' and entry_date between $3::date and $4::date
            and ($2::uuid is null or location_id = $2::uuid)) as entries_in,
         (select coalesce(sum(amount) filter (where direction = 'out'), 0) from pos_finance_entries where organization_id = $1
            and deleted_at is null and status = 'approved' and entry_date between $3::date and $4::date
            and ($2::uuid is null or location_id = $2::uuid)) as entries_out,
         (select coalesce(sum(amount), 0) from pos_finance_entries where organization_id = $1 and deleted_at is null
            and status = 'approved' and kind = 'top_up' and entry_date between $3::date and $4::date
            and ($2::uuid is null or location_id = $2::uuid)) as top_ups,
         (select coalesce(sum(amount) filter (where kind = 'top_up'), 0) from pos_finance_entries where organization_id = $1
            and deleted_at is null and status = 'pending' and ($2::uuid is null or location_id = $2::uuid)) as pending_top_ups,
         (select coalesce(sum(amount) filter (where kind = 'withdrawal'), 0) from pos_finance_entries where organization_id = $1
            and deleted_at is null and status = 'pending' and ($2::uuid is null or location_id = $2::uuid)) as withdrawals_due`,
      [org, branch, from, to, tz],
    );
    const moneyIn = money(num(flow?.collections) + num(flow?.entries_in));
    const moneyOut = money(flow?.entries_out);

    const monthly = await ctx.db.query<Row>(
      `select month, sum(inflow) as inflow, sum(outflow) as outflow from (
         select to_char(p.created_at at time zone $3, 'YYYY-MM') as month, p.amount as inflow, 0 as outflow
           from payments p join orders o on o.id = p.order_id
          where p.organization_id = $1 and o.status in ${PAID} and ($2::uuid is null or o.location_id = $2::uuid)
            and p.created_at >= date_trunc('month', now()) - interval '5 months'
         union all
         select to_char(entry_date, 'YYYY-MM'), case when direction = 'in' then amount else 0 end,
                case when direction = 'out' then amount else 0 end
           from pos_finance_entries where organization_id = $1 and deleted_at is null and status = 'approved'
            and ($2::uuid is null or location_id = $2::uuid) and entry_date >= date_trunc('month', now()) - interval '5 months'
       ) t group by month order by month`,
      [org, branch, tz],
    );
    const mix = await ctx.db.query<Row>(
      `select p.method, sum(p.amount) as amount from payments p join orders o on o.id = p.order_id
        where p.organization_id = $1 and o.status in ${PAID} and ($2::uuid is null or o.location_id = $2::uuid)
          and (p.created_at at time zone $5)::date between $3::date and $4::date
        group by p.method order by 2 desc`,
      [org, branch, from, to, tz],
    );
    const expenses = await ctx.db.query<Row>(
      `select coalesce(nullif(category, ''), 'Uncategorised') as category, sum(amount) as amount
         from pos_finance_entries where organization_id = $1 and deleted_at is null and status = 'approved' and direction = 'out'
          and entry_date between $3::date and $4::date and ($2::uuid is null or location_id = $2::uuid)
        group by 1 order by 2 desc limit 8`,
      [org, branch, from, to],
    );

    return c.json({
      data: {
        period: { from, to },
        cash_in_hand: bal('cash'),
        bank_balance: bal('bank'),
        upi_balance: bal('upi'),
        wallet_balance: bal('wallet'),
        total_balance: money(bal('cash') + bal('bank') + bal('upi') + bal('wallet')),
        today_sales: money(day?.sales),
        today_expense: money(day?.expense),
        today_collection: money(day?.collection),
        today_refund: 0,
        pending_settlements: money(day?.pending_settlements),
        supplier_payables: money(payables?.amount),
        customer_receivables: money(day?.receivables),
        money_in: moneyIn,
        money_out: moneyOut,
        net_cash_flow: money(moneyIn - moneyOut),
        partner_top_ups: money(flow?.top_ups),
        pending_top_ups: money(flow?.pending_top_ups),
        withdrawals_due: money(flow?.withdrawals_due),
        monthly: monthly.map((m) => ({ month: m.month, inflow: money(m.inflow), outflow: money(m.outflow), net: money(num(m.inflow) - num(m.outflow)) })),
        collection_mix: mix.map((m) => ({ method: m.method, amount: money(m.amount) })),
        expense_breakdown: expenses.map((e) => ({ category: e.category, amount: money(e.amount) })),
      },
    });
  });

  app.get('/payments', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'finance', 'read');
    const { from, to, tz } = period(c, ctx);
    const source = c.req.query('source') ?? 'all';
    if (!['all', 'pos', 'online'].includes(source)) throw unprocessable('source must be all, pos or online.');
    const limit = intParam(c.req.query('limit'), 200, 1000);
    const rows = await paymentRows(ctx, from, to, tz, source, limit);
    const all = source === 'all' ? rows : await paymentRows(ctx, from, to, tz, 'all', limit);
    const sum = (f: (r: Row) => boolean) => money(all.filter(f).reduce((s, r) => s + num(r.amount), 0));
    return c.json({
      data: rows,
      summary: {
        gross: sum((r) => r.status === 'completed'),
        online: sum((r) => r.source === 'online' && r.status === 'completed'),
        pos: sum((r) => r.source === 'pos' && r.status === 'completed'),
        cash: sum((r) => r.method === 'cash' && r.status === 'completed'),
        pending: sum((r) => r.status === 'pending_verification' || r.status === 'pending'),
        counts: {
          all: all.length,
          online: all.filter((r) => r.source === 'online').length,
          pos: all.filter((r) => r.source === 'pos').length,
        },
      },
    });
  });

  // ── entries ──
  mountTableResource(app, {
    path: 'entries',
    table: 'pos_finance_entries',
    module: 'finance',
    columns: {
      entry_date: 'date',
      direction: 'enum:in|out!',
      kind: 'enum:cash_register|top_up|withdrawal|capital|expense|transfer|other',
      account: 'enum:cash|bank|upi|wallet',
      category: 'text',
      amount: 'numeric!',
      party: 'text',
      reference: 'text',
      note: 'text',
      status: 'enum:pending|approved|rejected',
      location_id: 'uuid?',
    },
    locationColumn: 'location_id',
    filters: ['direction', 'kind', 'account', 'status', 'category'],
    order: [{ col: 'entry_date', ascending: false }, { col: 'created_at', ascending: false }],
    remove: 'soft',
    beforeCreate: (ctx, row) => {
      if (!(num(row.amount) > 0)) throw unprocessable('Amount must be more than zero.');
      if (row.kind === 'expense' && row.direction !== 'out') throw unprocessable('An expense is money out.');
      return { ...row, created_by: ctx.identity.user_id };
    },
    beforeUpdate: (_ctx, patch, existing) => {
      if (patch.amount !== undefined && !(num(patch.amount) > 0)) throw unprocessable('Amount must be more than zero.');
      if (existing.status !== 'pending' && patch.status !== undefined && patch.status !== existing.status) {
        throw conflict('Only a pending entry can be approved or rejected.');
      }
      return patch;
    },
  });

  for (const decision of ['approve', 'reject'] as const) {
    app.post(`/entries/:id/${decision}`, async (c) => {
      const ctx = ctxOf(c);
      requireCan(ctx, 'finance', 'write');
      const id = c.req.param('id');
      if (!isUuid(id)) throw notFound('This entry was not found.');
      const [row] = await ctx.db.query<Row>(
        `update pos_finance_entries set status = $3
          where id = $1 and organization_id = $2 and deleted_at is null and status = 'pending'
            and ($4::uuid is null or location_id = $4::uuid) returning *`,
        [id, ctx.m.organization_id, decision === 'approve' ? 'approved' : 'rejected', ctx.m.branch_scope],
      );
      if (!row) throw conflict('Only a pending entry of your branch can be approved or rejected.');
      await audit(ctx, decision === 'approve' ? 'Approved entry' : 'Rejected entry', 'Finance entry', id, { amount: num(row.amount) });
      return c.json({ data: row });
    });
  }

  // ── expenses ──
  mountTableResource(app, {
    path: 'expense-heads',
    table: 'pos_expense_heads',
    module: 'finance',
    columns: { name: 'text!', monthly_budget: 'numeric', active: 'bool' },
    order: [{ col: 'name' }],
    remove: 'hard',
  });

  app.get('/expenses/summary', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'finance', 'read');
    const month = c.req.query('month') ?? localDate(tzOf(ctx)).slice(0, 7);
    if (!/^\d{4}-\d{2}$/.test(month)) throw unprocessable('month must be YYYY-MM.');
    const rows = await ctx.db.query<Row>(
      `select coalesce(nullif(e.category, ''), 'Uncategorised') as category, sum(e.amount) as spent, count(*)::int as entries,
              max(h.monthly_budget) as budget
         from pos_finance_entries e
         left join pos_expense_heads h on h.organization_id = e.organization_id and lower(h.name) = lower(e.category)
        where e.organization_id = $1 and e.deleted_at is null and e.status = 'approved' and e.kind = 'expense'
          and to_char(e.entry_date, 'YYYY-MM') = $2 and ($3::uuid is null or e.location_id = $3::uuid)
        group by 1 order by 2 desc`,
      [ctx.m.organization_id, month, ctx.m.branch_scope],
    );
    return c.json({
      data: {
        month,
        total: money(rows.reduce((s, r) => s + num(r.spent), 0)),
        by_head: rows.map((r) => ({ category: r.category, spent: money(r.spent), entries: num(r.entries), budget: r.budget === null ? null : money(r.budget) })),
      },
    });
  });

  // ── settlements ──
  mountTableResource(app, {
    path: 'settlements',
    table: 'pos_settlements',
    module: 'finance',
    columns: {
      source: `${settlementSource}!`,
      amount: 'numeric!',
      utr: 'text',
      method: 'enum:bank_transfer|bank_deposit|upi|cheque',
      status: 'enum:pending|completed|failed',
      expected_on: 'date?',
      settled_at: 'timestamp?',
      note: 'text',
      location_id: 'uuid?',
    },
    locationColumn: 'location_id',
    filters: ['status', 'source'],
    order: [{ col: 'created_at', ascending: false }],
    remove: 'soft',
    beforeCreate: async (ctx, row) => {
      if (!(num(row.amount) > 0)) throw unprocessable('Amount must be more than zero.');
      const day = localDate(tzOf(ctx)).replace(/-/g, '');
      const [{ n }] = (await ctx.db.query<{ n: number }>(
        `select count(*)::int as n from pos_settlements where organization_id = $1 and settlement_no like $2`,
        [ctx.m.organization_id, `STL-${day}-%`],
      )) as [{ n: number }];
      const status = row.status ?? 'pending';
      return {
        ...row,
        status,
        settled_at: status === 'completed' ? (row.settled_at ?? new Date().toISOString()) : (row.settled_at ?? null),
        settlement_no: `STL-${day}-${String(n + 1).padStart(3, '0')}`,
        created_by: ctx.identity.user_id,
      };
    },
    beforeUpdate: (_ctx, patch, existing) => {
      if (patch.status === 'completed' && existing.status !== 'completed' && !patch.settled_at) {
        return { ...patch, settled_at: new Date().toISOString() };
      }
      return patch;
    },
  });

  app.get('/settlements-summary', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'finance', 'read');
    const [s] = await ctx.db.query<Row>(
      `select coalesce(sum(amount) filter (where status = 'completed'), 0) as settled,
              coalesce(sum(amount) filter (where status = 'pending'), 0) as pending,
              count(*)::int as total,
              count(*) filter (where status = 'completed')::int as completed,
              count(*) filter (where status = 'pending')::int as pending_count,
              count(*) filter (where status = 'failed')::int as failed
         from pos_settlements where organization_id = $1 and deleted_at is null and ($2::uuid is null or location_id = $2::uuid)`,
      [ctx.m.organization_id, ctx.m.branch_scope],
    );
    const [last] = await ctx.db.query<Row>(
      `select amount, settled_at from pos_settlements where organization_id = $1 and deleted_at is null and status = 'completed'
          and ($2::uuid is null or location_id = $2::uuid) order by settled_at desc nulls last limit 1`,
      [ctx.m.organization_id, ctx.m.branch_scope],
    );
    const [next] = await ctx.db.query<Row>(
      `select amount, expected_on from pos_settlements where organization_id = $1 and deleted_at is null and status = 'pending'
          and ($2::uuid is null or location_id = $2::uuid) order by expected_on nulls last, created_at limit 1`,
      [ctx.m.organization_id, ctx.m.branch_scope],
    );
    return c.json({
      data: {
        total_settled: money(s?.settled),
        pending_amount: money(s?.pending),
        counts: { all: num(s?.total), completed: num(s?.completed), pending: num(s?.pending_count), failed: num(s?.failed) },
        last: last ? { amount: money(last.amount), settled_at: last.settled_at } : null,
        next: next ? { amount: money(next.amount), expected_on: next.expected_on } : null,
      },
    });
  });

  // ── documents ──
  mountTableResource(app, {
    path: 'documents',
    table: 'pos_business_documents',
    module: 'finance',
    columns: {
      name: 'text!',
      doc_type: 'enum:tax|food_safety|business|safety|liquor|environment|other',
      doc_no: 'text',
      issue_date: 'date?',
      expiry_date: 'date?',
      file_url: 'text?',
      review_status: 'enum:pending|verified',
      note: 'text',
      location_id: 'uuid?',
    },
    locationColumn: 'location_id',
    filters: ['doc_type', 'review_status'],
    order: [{ col: 'expiry_date', ascending: true }, { col: 'name' }],
    remove: 'soft',
    beforeCreate: (ctx, row) => {
      if (row.issue_date && row.expiry_date && String(row.expiry_date) < String(row.issue_date)) {
        throw unprocessable('The expiry date is before the issue date.');
      }
      return { ...row, created_by: ctx.identity.user_id };
    },
  });

  app.get('/documents-summary', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'finance', 'read');
    const today = localDate(tzOf(ctx));
    const [s] = await ctx.db.query<Row>(
      `select count(*)::int as total,
              count(*) filter (where expiry_date is null or expiry_date > $2::date + 90)::int as active,
              count(*) filter (where expiry_date between $2::date and $2::date + 90)::int as expiring,
              count(*) filter (where expiry_date < $2::date)::int as expired,
              count(*) filter (where review_status = 'pending')::int as pending_review
         from pos_business_documents
        where organization_id = $1 and deleted_at is null and ($3::uuid is null or location_id = $3::uuid)`,
      [ctx.m.organization_id, today, ctx.m.branch_scope],
    );
    return c.json({
      data: { total: num(s?.total), active: num(s?.active), expiring_soon: num(s?.expiring), expired: num(s?.expired), pending_review: num(s?.pending_review), today },
    });
  });

  return app;
}
