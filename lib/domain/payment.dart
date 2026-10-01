// Payment/finance domain — PRD §9 finance requirements: "Separate order,
// kitchen, delivery, payment and settlement states; do not overload one
// status." Payment is therefore its own record, not a field bolted onto
// LocalOrderStatus. Only cash is modeled as ever reaching `recorded`
// (confirmed) — D03/D09: cash-first pilot, digital payments remain
// pending verification until a real provider integration exists. See
// docs/DECISIONS-AND-QUESTIONS.txt.

enum PaymentMethod { cash }

class CashPayment {
  const CashPayment(
      {required this.paymentId,
      required this.clientOrderId,
      required this.amountMinor,
      required this.receivedMinor,
      required this.recordedAt});
  final String paymentId, clientOrderId;

  /// What was owed (order total at the time of payment).
  final int amountMinor;

  /// What the cashier actually collected.
  final int receivedMinor;
  final DateTime recordedAt;

  int get changeMinor => receivedMinor - amountMinor;
}

// ---------------------------------------------------------------------
// Tender keys and verification (shared by POS and Operations)
// ---------------------------------------------------------------------

/// Tender keys stored in `payments.method` / `orders.payment_method`.
const cashTender = 'cash';
const cardTender = 'card';
const upiTender = 'upi';

/// A split tender is stored as ONE payment row (the `payments` table
/// allows one row per order), with a readable method text such as
/// `split: cash ₹120 + upi ₹80`. The backend keeps the raw text and maps
/// it to the `other` tender.
bool isSplitTender(String method) =>
    method.trim().toLowerCase().startsWith('split');

/// Card, UPI and any split that includes them cannot be confirmed by the
/// device: there is no payment-provider integration, and a staff tap or a
/// typed UPI reference is not provider verification (PRD §9). They are
/// recorded but stay "pending verification" until an authorised user
/// verifies them. Cash is final when recorded.
bool tenderNeedsVerification(String method) {
  final m = method.trim().toLowerCase();
  if (m == cashTender) return false;
  if (isSplitTender(m)) {
    return RegExp(r'\b(card|upi)\b').hasMatch(m) ||
        !RegExp(r'\bcash\b').hasMatch(m);
  }
  return true;
}

/// Where an order's money stands, derived from the order status and its
/// payment row (never stored as a status of its own).
enum OrderPaymentState {
  /// No payment recorded yet.
  unpaid,

  /// Card / UPI / split recorded, not yet verified by an authorised user.
  pendingVerification,

  /// Cash recorded, or a digital payment verified (order settled).
  paid,
}

/// [settled]: the order's lifecycle reached settled; [recordedMethod]: the
/// method on its payment row, null when there is none.
OrderPaymentState derivePaymentState(
    {required bool settled, required String? recordedMethod}) {
  if (settled) return OrderPaymentState.paid;
  if (recordedMethod == null) return OrderPaymentState.unpaid;
  return tenderNeedsVerification(recordedMethod)
      ? OrderPaymentState.pendingVerification
      : OrderPaymentState.paid;
}
