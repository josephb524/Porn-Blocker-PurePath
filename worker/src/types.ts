/// Environment bound by Cloudflare Workers from `wrangler.toml` + secrets.
export interface Env {
  /// The iOS app's bundle identifier — used to reject JWSes from other apps.
  APPLE_BUNDLE_ID: string;
  /// Fireworks model path, e.g. `accounts/fireworks/models/gpt-oss-120b`.
  /// Optional; the proxy falls back to a sensible default.
  FIREWORKS_MODEL?: string;
  /// Fireworks API key (`fw_…`). Set via `wrangler secret put`.
  FIREWORKS_API_KEY: string;
  /// Optional KV namespace holding daily message-quota counters.
  SUB_CACHE?: KVNamespace;
  /// Optional per-user burst rate limiter (ratelimit unsafe binding).
  RATE_LIMITER?: { limit(input: { key: string }): Promise<{ success: boolean }> };
}

export interface ChatRequest {
  signedTransaction: string;
  messages: ChatMessage[];
}

export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

/// The decoded payload of an Apple StoreKit 2 signed transaction JWS.
/// Fields are documented at:
///   https://developer.apple.com/documentation/appstoreserverapi/jwstransactiondecodedpayload
export interface TransactionPayload {
  bundleId: string;
  productId: string;
  /// Milliseconds since epoch.
  expiresDate?: number;
  /// Milliseconds since epoch — present only when the entitlement was revoked.
  revocationDate?: number;
  originalTransactionId?: string;
}
