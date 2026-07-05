import type { Env, TransactionPayload } from './types';

/// Product IDs allowed to use the buddy-chat endpoint. Keep this in sync
/// with `SubscriptionManager.swift` and App Store Connect.
const VALID_PRODUCT_IDS = new Set<string>(['pornBlocker', 'monthlyPornBlocker']);

export type VerifyResult =
  | { ok: true; payload: TransactionPayload }
  | { ok: false; reason: string; status: number };

/// Decodes the JWS payload locally and checks bundle / product / expiry /
/// revocation against the configured allow-list.
///
/// **Note:** we trust the JWS payload WITHOUT verifying Apple's signature.
/// This does not stop deliberate forgery — bundleId/productIds are public
/// (extractable from the shipped binary) and expiry just needs to be in the
/// future, so anyone inspecting the app's traffic can mint a passing JWS and
/// rotate originalTransactionId to dodge per-user rate keys. The claim checks
/// only keep honest clients honest; abuse mitigation is the burst limiter +
/// KV daily quota in index.ts. If abuse appears, add real signature
/// verification against Apple's root cert (x5c chain via crypto.subtle.verify)
/// — backward compatible, since real app versions send genuine Apple JWS.
export function verifySignedTransaction(jws: string, env: Env): VerifyResult {
  let payload: TransactionPayload;
  try {
    payload = decodeJWS(jws);
  } catch {
    return { ok: false, reason: 'jws_decode_failed', status: 401 };
  }

  if (payload.bundleId !== env.APPLE_BUNDLE_ID) {
    return { ok: false, reason: 'bundle_mismatch', status: 401 };
  }
  if (!VALID_PRODUCT_IDS.has(payload.productId)) {
    return { ok: false, reason: 'product_not_allowed', status: 402 };
  }
  if (typeof payload.revocationDate === 'number' && payload.revocationDate > 0) {
    return { ok: false, reason: 'revoked', status: 402 };
  }
  if (typeof payload.expiresDate === 'number' && payload.expiresDate < Date.now()) {
    return { ok: false, reason: 'expired', status: 402 };
  }
  return { ok: true, payload };
}

function decodeJWS(jws: string): TransactionPayload {
  const parts = jws.split('.');
  if (parts.length !== 3) throw new Error('not_a_jws');
  const payloadB64Url = parts[1];
  if (!payloadB64Url) throw new Error('empty_payload');
  // JWS uses base64url; atob expects standard base64.
  const padded = payloadB64Url.replace(/-/g, '+').replace(/_/g, '/');
  const text = atob(padded);
  return JSON.parse(text) as TransactionPayload;
}
