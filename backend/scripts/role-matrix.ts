/// Prints the role contract as Markdown tables (docs/VENDOR-PANEL-REPORT.md):
/// what each built-in role opens and may do. Run: npx tsx scripts/role-matrix.ts
import { defaultScreens, SCREENS } from '../src/access.js';
import {
  BRANCH_BOUND_ROLES,
  can,
  canPlaceOrders,
  canTakePayments,
  canVerifyPayments,
  panelFor,
  POS_ROLE_NAMES,
  POS_ROLES,
  type Module,
} from '../src/permissions.js';

const yes = (b: boolean) => (b ? '✓' : '–');
const rights = (role: string, m: Module) => ['read', 'write', 'delete'].filter((a) => can(role, m, a as never)).map((a) => a[0]!.toUpperCase()).join('') || '–';

const MODULES: [Module, string][] = [
  ['franchise', 'Franchise'],
  ['master', 'Master'],
  ['operations', 'Operations'],
  ['staff', 'Staff'],
  ['crm', 'CRM'],
  ['marketing', 'Marketing'],
  ['finance', 'Finance'],
  ['integrations', 'Integrations'],
  ['tasks', 'Tasks'],
  ['settings', 'Settings'],
];

console.log(`| Role | Key | App | Screens | ${MODULES.map(([, n]) => n).join(' | ')} | Branch-bound | Orders | Take pay | Verify |`);
console.log('|---|---|---|---|' + MODULES.map(() => '---|').join('') + '---|---|---|---|');
for (const r of POS_ROLES) {
  const cells = [
    POS_ROLE_NAMES[r],
    `\`${r}\``,
    panelFor(r),
    String(defaultScreens(r).length),
    ...MODULES.map(([m]) => rights(r, m)),
    yes(BRANCH_BOUND_ROLES.has(r)),
    yes(canPlaceOrders(r)),
    yes(canTakePayments(r)),
    yes(canVerifyPayments(r)),
  ];
  console.log(`| ${cells.join(' | ')} |`);
}

console.log('\n| Screen | Id | ' + POS_ROLES.map((r) => `\`${r}\``).join(' | ') + ' |');
console.log('|---|---|' + POS_ROLES.map(() => ':-:').join('|') + '|');
const sets = Object.fromEntries(POS_ROLES.map((r) => [r, new Set(defaultScreens(r))]));
for (const s of SCREENS) {
  console.log(`| ${s.group} · ${s.label} | \`${s.id}\` | ` + POS_ROLES.map((r) => (sets[r]!.has(s.id) ? '●' : '')).join(' | ') + ' |');
}
