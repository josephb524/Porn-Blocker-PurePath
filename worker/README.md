# Buddy Chat Worker

The Cloudflare Worker behind the **Buddy** tab. It:

1. Verifies the iOS app's StoreKit 2 **signed transaction JWS** locally
   (`src/verify.ts`) — checks bundle ID, product ID, expiry, revocation.
2. Proxies the conversation to **Fireworks AI** with streaming
   (`src/fireworks.ts`), using their OpenAI-compatible chat completions API.
3. Re-frames Fireworks' SSE event stream into a tiny `data: {"text":"…"}`
   format the iOS client can consume directly.

Endpoint: **`POST /chat`** — body `{ signedTransaction, messages }`.

## One-time setup

You need a Cloudflare account (free tier is fine) and a Fireworks API key.

```sh
cd worker
npm install
```

Set the Fireworks API key as a Worker secret:

```sh
npx wrangler secret put FIREWORKS_API_KEY
# paste your fw_… key when prompted
```

The non-secret vars live in [`wrangler.toml`](wrangler.toml). The defaults:

| Var | Default | Notes |
|---|---|---|
| `APPLE_BUNDLE_ID` | `com.jose.pimentel.Porn-Blocker` | Must match the iOS app's bundle ID exactly. |
| `FIREWORKS_MODEL` | `accounts/fireworks/models/gpt-oss-120b` | See <https://fireworks.ai/models>; `llama-v3p3-70b-instruct` is a good conversational alternative. |

Allowed product IDs are hardcoded in `src/verify.ts`:
`pornBlocker`, `pornBlockerMonthly`. If you rename them in App Store Connect,
update that file too.

## Deploy

```sh
npx wrangler deploy
```

Wrangler prints the deployed URL (e.g. `https://porn-blocker-buddy.<your-subdomain>.workers.dev`).
**Open `Porn Blocker/BuddyChatService.swift` and set `endpoint` to that URL
with `/chat` appended.** That's the one hardcoded URL the iOS app holds.

## Develop & debug

```sh
npx wrangler dev                  # local dev server
npx wrangler tail --format=pretty # stream live production logs
npm run typecheck                 # static type check
```

Useful log lines:

| Log | Meaning |
|---|---|
| `verify_failed { reason: 'bundle_mismatch' }` | `APPLE_BUNDLE_ID` in `wrangler.toml` doesn't match the JWS. Fix and redeploy. |
| `verify_failed { reason: 'product_not_allowed' }` | A product ID isn't in `VALID_PRODUCT_IDS` in `verify.ts`. |
| `verify_failed { reason: 'expired' }` | Subscription's `expiresDate` is in the past. Real expiry, or sandbox cadence in dev. |
| `verify_failed { reason: 'revoked' }` | Apple revoked the transaction (refund). |
| `fireworks_error { status, body }` | Fireworks responded non-2xx. Common causes: bad model path, invalid API key, rate limit. |
| `worker_unhandled_error` | Top-level catch. The body has the error message. |

## HTTP error responses

The worker returns JSON `{ "error": "<reason>" }` for non-2xx:

| Status | `error` | Cause |
|---|---|---|
| 400 | `bad_json` / `missing_signed_transaction` / `missing_messages` / `too_many_messages` / `bad_message_shape` | Malformed request. |
| 401 | `jws_decode_failed` / `bundle_mismatch` | The JWS isn't ours. |
| 402 | `product_not_allowed` / `expired` / `revoked` | Subscription gate failed. |
| 404 | (text) | Wrong path; only `/chat` exists. |
| 500 | `internal_error` | Unhandled exception — check `wrangler tail`. |
| 502/5xx | `upstream_error` | Fireworks returned non-2xx; check `fireworks_error` log. |

## Tuning the assistant

- **Tone, safety, format:** edit `src/prompt.ts` (the system prompt). The
  prompt is sent as the first `role: "system"` message in every request.
- **Response length:** bump `MAX_TOKENS` in `src/fireworks.ts` if replies
  feel cut off (raises per-request cost).
- **Conversation history depth:** lower `MAX_MESSAGES` in `src/index.ts`
  to cap how much history is sent on each turn (currently 40).
- **Model:** change `FIREWORKS_MODEL` in `wrangler.toml`. No code change
  needed; redeploy.

## Security note

The worker decodes the JWS payload without verifying Apple's signature.
Forging a JWS that decodes to a valid bundle + allow-listed product + a
future `expiresDate` would require compromising Apple's signing
infrastructure. If you ever see abuse, add `crypto.subtle.verify` against
Apple's root certificate.

## Cost note

- Fireworks charges per input + output token, model-dependent. The default
  (`gpt-oss-120b`) is cheap per multi-turn chat.
- Multi-turn history is sent on every request — grows linearly with
  conversation length, which is why the worker caps at 40 messages.
- Cloudflare Workers free tier covers the proxying itself.
