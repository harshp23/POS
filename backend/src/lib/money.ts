/// The device keeps money in integer paise (PRD §9: "Amounts use integer
/// minor units"); the OS tables use numeric(10,2) rupees. Conversions go
/// through here so rounding is the same everywhere.

export const toRupees = (minor: number): number => Math.round(minor) / 100;

export const toMinor = (rupees: unknown): number => {
  const n = typeof rupees === 'string' ? Number(rupees) : (rupees as number);
  return Number.isFinite(n) ? Math.round(n * 100) : 0;
};

/// Rounds a rupee amount to 2 decimals (half away from zero on paise).
export const round2 = (rupees: number): number => Math.round(rupees * 100) / 100;

export interface OrderTotals {
  subtotal: number;
  discount: number;
  gst_amount: number;
  total: number;
}

/// Same arithmetic as the device's OpsOrder (discount before tax, tax on
/// the discounted amount), in rupees.
export function orderTotals(lines: { qty: number; unit_price: number }[], discountPct: number, gstPct: number): OrderTotals {
  const subtotalMinor = lines.reduce((s, l) => s + Math.round(l.unit_price * 100) * l.qty, 0);
  const discountMinor = Math.round((subtotalMinor * discountPct) / 100);
  const taxMinor = Math.round(((subtotalMinor - discountMinor) * gstPct) / 100);
  return {
    subtotal: toRupees(subtotalMinor),
    discount: toRupees(discountMinor),
    gst_amount: toRupees(taxMinor),
    total: toRupees(subtotalMinor - discountMinor + taxMinor),
  };
}
