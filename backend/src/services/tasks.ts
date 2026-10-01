import { Hono } from 'hono';
import { z } from 'zod';
import { requireCan, type RequestContext } from '../context.js';
import { TextArray } from '../db/sql.js';
import type { Row } from '../db/types.js';
import { ctxOf, readJson, type Env } from '../http.js';
import { conflict, notFound, unprocessable } from '../lib/errors.js';
import { isUuid } from '../lib/ids.js';
import { localDate, tzOf } from '../lib/time.js';
import { actorName, audit, num, sectionGuard } from './section.js';

/// Task Manager (/v1/tasks): operational tasks assigned to staff, with a
/// checklist, evidence rules, manager verification and a timeline.
///
///   assigned → in_progress → submitted (awaiting verification) → completed
///                                        ↘ failed → reassigned → …
/// Without "manager approval" a submitted task completes at once.

type Status = 'draft' | 'assigned' | 'in_progress' | 'submitted' | 'completed' | 'failed' | 'reassigned';

/// Task states as people say them.
const STATUS_WORDS: Record<string, string> = {
  draft: 'a draft',
  assigned: 'assigned',
  in_progress: 'in progress',
  submitted: 'waiting for verification',
  completed: 'completed',
  failed: 'failed',
  reassigned: 'reassigned',
};
const statusWord = (s: unknown) => STATUS_WORDS[String(s)] ?? String(s).replace(/_/g, ' ');
const CADENCE_NOTES: Record<string, string> = { daily: 'Daily task', weekly: 'Weekly task', monthly: 'Monthly task' };

const checklistItem = z.object({ text: z.string().trim().min(1).max(200), done: z.boolean().default(false) }).strict();

const taskFields = {
  title: z.string().trim().min(1, 'Give the task a title.').max(160),
  description: z.string().trim().max(2000),
  priority: z.enum(['low', 'medium', 'high']),
  category: z.string().trim().max(60),
  assignee_staff_id: z.string().uuid().nullable(),
  roles: z.array(z.string().trim().min(1).max(40)).max(10),
  due_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable(),
  cadence: z.enum(['once', 'daily', 'weekly', 'monthly']),
  photo_required: z.boolean(),
  checklist_required: z.boolean(),
  approval_required: z.boolean(),
  video_required: z.boolean(),
  checklist: z.array(checklistItem).max(30),
  location_id: z.string().uuid().nullable(),
};
const taskCreate = z
  .object(taskFields)
  .partial()
  .required({ title: true })
  .extend({ draft: z.boolean().default(false) })
  .strict();
const taskPatch = z.object(taskFields).partial().strict();

async function event(ctx: RequestContext, taskId: string, name: string, note = '') {
  await ctx.db.query(
    `insert into pos_task_events (organization_id, task_id, event, note, actor_name, created_by) values ($1, $2, $3, $4, $5, $6)`,
    [ctx.m.organization_id, taskId, name, note, actorName(ctx), ctx.identity.user_id],
  );
}

async function assignee(ctx: RequestContext, staffId: string | null | undefined) {
  if (!staffId) return { name: '', role: '' };
  const [s] = await ctx.db.query<Row>(
    `select full_name, designation, location_id from pos_staff where id = $1 and organization_id = $2 and deleted_at is null`,
    [staffId, ctx.m.organization_id],
  );
  if (!s) throw unprocessable('That staff member was not found.');
  if (ctx.m.branch_scope && s.location_id && s.location_id !== ctx.m.branch_scope) throw unprocessable('That staff member works at another branch.');
  return { name: String(s.full_name), role: String(s.designation ?? '') };
}

async function oneTask(ctx: RequestContext, id: string): Promise<Row> {
  if (!isUuid(id)) throw notFound('This task was not found.');
  const [row] = await ctx.db.query<Row>(
    `select * from pos_tasks where id = $1 and organization_id = $2 and deleted_at is null
        and ($3::uuid is null or location_id is null or location_id = $3::uuid)`,
    [id, ctx.m.organization_id, ctx.m.branch_scope],
  );
  if (!row) throw notFound('This task was not found.');
  return row;
}

const withOverdue = (r: Row, today: string): Row => ({
  ...r,
  overdue: !!r.due_date && String(r.due_date).slice(0, 10) < today && !['completed', 'draft'].includes(String(r.status)),
});

async function setStatus(ctx: RequestContext, id: string, status: Status, extra: Row = {}) {
  const cols = Object.keys(extra);
  const [row] = await ctx.db.query<Row>(
    `update pos_tasks set status = $3${cols.map((k, i) => `, ${k} = $${i + 4}`).join('')}
      where id = $1 and organization_id = $2 returning *`,
    [id, ctx.m.organization_id, status, ...Object.values(extra)],
  );
  return row!;
}

export function tasksRoutes(): Hono<Env> {
  const app = new Hono<Env>();
  app.use('*', sectionGuard('task_manager'));

  app.get('/tasks', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'tasks', 'read');
    const today = localDate(tzOf(ctx));
    const q = (k: string) => c.req.query(k) || null;
    const tab = c.req.query('tab') ?? 'all';
    let mine: string | null = null;
    if (tab === 'mine') {
      const [s] = await ctx.db.query<Row>(`select id from pos_staff where organization_id = $1 and user_id = $2 and deleted_at is null`, [
        ctx.m.organization_id,
        ctx.identity.user_id,
      ]);
      mine = (s?.id as string) ?? '00000000-0000-0000-0000-000000000000';
    }
    const rows = await ctx.db.query<Row>(
      `select * from pos_tasks
        where organization_id = $1 and deleted_at is null
          and ($2::uuid is null or location_id is null or location_id = $2::uuid)
          and ($3::text is null or status = $3) and ($4::text is null or priority = $4)
          and ($5::uuid is null or assignee_staff_id = $5::uuid)
          and ($6::date is null or due_date >= $6::date) and ($7::date is null or due_date <= $7::date)
        order by coalesce(due_date, '9999-12-31'), created_at desc limit 500`,
      [ctx.m.organization_id, ctx.m.branch_scope, q('status'), q('priority'), mine ?? q('assignee'), q('from'), q('to')],
    );
    let list = rows.map((r) => withOverdue(r, today));
    if (tab === 'active') list = list.filter((r) => ['assigned', 'in_progress', 'submitted', 'reassigned'].includes(String(r.status)));
    if (tab === 'completed') list = list.filter((r) => r.status === 'completed');
    if (tab === 'failed') list = list.filter((r) => r.status === 'failed' || r.overdue);
    const monthStart = `${today.slice(0, 7)}-01`;
    const [stats] = await ctx.db.query<Row>(
      `select count(*) filter (where created_at >= $3::date)::int as this_month,
              count(*) filter (where status in ('in_progress', 'submitted'))::int as in_progress,
              count(*) filter (where status = 'completed')::int as completed,
              count(*) filter (where status = 'failed' or (due_date < $4::date and status not in ('completed', 'draft')))::int as failed_overdue
         from pos_tasks where organization_id = $1 and deleted_at is null
          and ($2::uuid is null or location_id is null or location_id = $2::uuid)`,
      [ctx.m.organization_id, ctx.m.branch_scope, monthStart, today],
    );
    return c.json({
      data: list,
      summary: {
        total_this_month: num(stats?.this_month),
        in_progress: num(stats?.in_progress),
        completed: num(stats?.completed),
        failed_or_overdue: num(stats?.failed_overdue),
      },
    });
  });

  app.get('/assignees', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'tasks', 'read');
    const rows = await ctx.db.query<Row>(
      `select id, full_name, designation, location_id from pos_staff
        where organization_id = $1 and deleted_at is null and status = 'active'
          and ($2::uuid is null or location_id = $2::uuid)
        order by full_name`,
      [ctx.m.organization_id, ctx.m.branch_scope],
    );
    return c.json({ data: rows });
  });

  app.get('/tasks/:id', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'tasks', 'read');
    const task = await oneTask(ctx, c.req.param('id'));
    const events = await ctx.db.query<Row>(`select * from pos_task_events where task_id = $1 order by seq`, [task.id]);
    return c.json({ data: { ...withOverdue(task, localDate(tzOf(ctx))), events } });
  });

  app.post('/tasks', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'tasks', 'write');
    const { draft, ...body } = await readJson(c, taskCreate);
    if (!draft && !body.assignee_staff_id) throw unprocessable('Pick who does the task, or save it as a draft.');
    const who = await assignee(ctx, body.assignee_staff_id);
    const location = body.location_id ?? ctx.m.branch_scope ?? ctx.location?.id ?? null;
    if (ctx.m.branch_scope && location !== ctx.m.branch_scope) throw unprocessable('You can only add tasks for your branch.');
    const [row] = await ctx.db.insert<Row>('pos_tasks', [
      {
        ...body,
        roles: new TextArray(body.roles ?? []),
        checklist: JSON.stringify(body.checklist ?? []),
        location_id: location,
        assignee_name: who.name,
        assignee_role: who.role,
        status: draft ? 'draft' : 'assigned',
        organization_id: ctx.m.organization_id,
        created_by: ctx.identity.user_id,
        created_by_name: actorName(ctx),
      },
    ]);
    const id = String(row!.id);
    await event(ctx, id, 'Task created', (body.cadence && CADENCE_NOTES[body.cadence]) || '');
    if (!draft) await event(ctx, id, 'Task assigned', `Assigned to ${who.name}${who.role ? ` (${who.role})` : ''}`);
    await audit(ctx, draft ? 'Saved task draft' : 'Assigned task', 'Task', id, { title: body.title });
    return c.json({ data: row }, 201);
  });

  app.patch('/tasks/:id', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'tasks', 'write');
    const task = await oneTask(ctx, c.req.param('id'));
    if (task.status === 'completed') throw conflict('A completed task cannot be edited.');
    const body = await readJson(c, taskPatch);
    const patch: Row = { ...body };
    if (body.roles) patch.roles = new TextArray(body.roles);
    if (body.checklist) patch.checklist = JSON.stringify(body.checklist);
    if (body.assignee_staff_id !== undefined) {
      const who = await assignee(ctx, body.assignee_staff_id);
      patch.assignee_name = who.name;
      patch.assignee_role = who.role;
    }
    let status = task.status as Status;
    if (status === 'draft' && patch.assignee_staff_id) status = 'assigned';
    const row = await setStatus(ctx, String(task.id), status, patch);
    if (status !== task.status) await event(ctx, String(task.id), 'Task assigned', `Assigned to ${row.assignee_name}`);
    return c.json({ data: row });
  });

  app.delete('/tasks/:id', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'tasks', 'delete');
    const task = await oneTask(ctx, c.req.param('id'));
    await ctx.db.query(`update pos_tasks set deleted_at = now() where id = $1 and organization_id = $2`, [task.id, ctx.m.organization_id]);
    await audit(ctx, 'Deleted task', 'Task', String(task.id), { title: task.title });
    return c.body(null, 204);
  });

  app.post('/tasks/:id/start', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'tasks', 'write');
    const task = await oneTask(ctx, c.req.param('id'));
    if (!['assigned', 'reassigned'].includes(String(task.status))) throw conflict(`This task is ${statusWord(task.status)}; it cannot be started.`);
    const row = await setStatus(ctx, String(task.id), 'in_progress');
    await event(ctx, String(task.id), 'Task started', `${task.assignee_name} started the task`);
    return c.json({ data: row });
  });

  app.post('/tasks/:id/checklist', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'tasks', 'write');
    const task = await oneTask(ctx, c.req.param('id'));
    if (!['assigned', 'reassigned', 'in_progress'].includes(String(task.status))) throw conflict(`This task is ${statusWord(task.status)}; its checklist is locked.`);
    const body = await readJson(c, z.object({ index: z.number().int().min(0), done: z.boolean() }).strict());
    const list = ((task.checklist as { text: string; done: boolean }[]) ?? []).map((i) => ({ ...i }));
    if (!list[body.index]) throw notFound(`No checklist item ${body.index + 1}.`);
    list[body.index]!.done = body.done;
    const status = task.status === 'in_progress' ? 'in_progress' : 'in_progress';
    const row = await setStatus(ctx, String(task.id), status, { checklist: JSON.stringify(list) });
    if (task.status !== 'in_progress') await event(ctx, String(task.id), 'Task started', `${task.assignee_name} started the task`);
    return c.json({ data: row });
  });

  app.post('/tasks/:id/submit', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'tasks', 'write');
    const task = await oneTask(ctx, c.req.param('id'));
    if (!['assigned', 'reassigned', 'in_progress'].includes(String(task.status))) throw conflict(`This task is ${statusWord(task.status)}; it cannot be submitted.`);
    const body = await readJson(
      c,
      z.object({ evidence_url: z.union([z.string().trim().url().max(500), z.literal('')]).default(''), note: z.string().trim().max(1000).default('') }).strict(),
    );
    const list = (task.checklist as { text: string; done: boolean }[]) ?? [];
    const done = list.filter((i) => i.done).length;
    if (task.checklist_required && done < list.length) throw unprocessable(`Tick every checklist item first (${done}/${list.length} done).`);
    if (task.photo_required && !body.evidence_url) throw unprocessable('This task needs a photo: add the photo link.');
    const needsReview = task.approval_required === true;
    const row = await setStatus(ctx, String(task.id), needsReview ? 'submitted' : 'completed', {
      evidence_url: body.evidence_url || null,
      evidence_note: body.note,
    });
    const id = String(task.id);
    await event(ctx, id, 'Task executed', `Checklist ${done}/${list.length} completed`);
    if (body.evidence_url) await event(ctx, id, 'Evidence uploaded', body.evidence_url);
    await event(ctx, id, needsReview ? 'Submitted for sign-off' : 'Task completed', needsReview ? 'Awaiting manager verification' : '');
    return c.json({ data: row });
  });

  app.post('/tasks/:id/verify', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'tasks', 'write');
    const task = await oneTask(ctx, c.req.param('id'));
    if (task.status !== 'submitted') throw conflict('Only a task awaiting verification can be approved or failed.');
    const body = await readJson(
      c,
      z
        .object({
          approved: z.boolean(),
          note: z.string().trim().max(1000).default(''),
          failure_reason: z.string().trim().max(1000).default(''),
        })
        .strict(),
    );
    if (!body.approved && !body.failure_reason) throw unprocessable('Say why the task failed.');
    const id = String(task.id);
    const row = await setStatus(ctx, id, body.approved ? 'completed' : 'failed', {
      reviewed_by_name: actorName(ctx),
      reviewed_at: new Date().toISOString(),
      failure_reason: body.approved ? '' : body.failure_reason,
      corrective_note: body.note,
    });
    if (body.approved) {
      await event(ctx, id, 'Verification approved', body.note);
      await event(ctx, id, 'Task completed', 'Audit chain closed');
    } else {
      await event(ctx, id, 'Verification failed', body.failure_reason);
    }
    await audit(ctx, body.approved ? 'Approved task' : 'Failed task', 'Task', id, { title: task.title });
    return c.json({ data: row });
  });

  app.post('/tasks/:id/reassign', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'tasks', 'write');
    const task = await oneTask(ctx, c.req.param('id'));
    if (task.status === 'completed' || task.status === 'draft') throw conflict(task.status === 'draft' ? 'A draft task cannot be reassigned.' : 'A completed task cannot be reassigned.');
    const body = await readJson(
      c,
      z
        .object({
          assignee_staff_id: z.string().uuid(),
          due_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable().default(null),
          note: z.string().trim().max(1000).default(''),
        })
        .strict(),
    );
    const who = await assignee(ctx, body.assignee_staff_id);
    const list = ((task.checklist as { text: string; done: boolean }[]) ?? []).map((i) => ({ ...i, done: false }));
    const id = String(task.id);
    const row = await setStatus(ctx, id, 'reassigned', {
      assignee_staff_id: body.assignee_staff_id,
      assignee_name: who.name,
      assignee_role: who.role,
      due_date: body.due_date ?? task.due_date,
      corrective_note: body.note,
      checklist: JSON.stringify(list),
      evidence_url: null,
    });
    if (task.status === 'failed') await event(ctx, id, 'Corrective action initiated', body.note);
    await event(ctx, id, 'Task reassigned', `Assigned to ${who.name}${who.role ? ` (${who.role})` : ''}`);
    return c.json({ data: row });
  });

  return app;
}
