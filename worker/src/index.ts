import type { Env, ChatRequest } from './types';
import { verifySignedTransaction } from './verify';
import { proxyChat } from './fireworks';

const MAX_MESSAGES = 40;
const ALLOWED_ROLES = new Set<string>(['user', 'assistant']);
// The app caps history at 21 messages and assistant replies at 1024 tokens,
// so honest clients stay far below these. They exist to stop cost abuse via
// huge payloads — TypeScript types aren't enforced at runtime.
const MAX_MESSAGE_CHARS = 16_000;
const MAX_TOTAL_CHARS = 200_000;
const DAILY_MESSAGE_LIMIT = 200;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      if (request.method !== 'POST') {
        return new Response('Method not allowed', { status: 405 });
      }
      const url = new URL(request.url);
      if (url.pathname !== '/chat') {
        return new Response('Not found', { status: 404 });
      }

      let body: ChatRequest;
      try {
        body = (await request.json()) as ChatRequest;
      } catch {
        return jsonError(400, 'bad_json');
      }

      const validation = validate(body);
      if (validation) return validation;

      const verify = verifySignedTransaction(body.signedTransaction, env);
      if (!verify.ok) {
        console.log('verify_failed', { reason: verify.reason });
        return jsonError(verify.status, verify.reason);
      }

      // Burst limit per user (the ratelimit binding only supports 10 s / 60 s
      // periods, so it can't enforce a daily cap — that lives in KV below).
      const rateKey = verify.payload.originalTransactionId ?? 'unknown';
      if (env.RATE_LIMITER) {
        const rate = await env.RATE_LIMITER.limit({ key: rateKey });
        if (!rate.success) return jsonError(429, 'rate_limited');
      }

      // Daily quota in KV. Eventually consistent, so rapid parallel requests
      // may slip past the exact count — the burst limiter covers that window.
      if (env.SUB_CACHE) {
        const day = new Date().toISOString().slice(0, 10);
        const key = `quota:${rateKey}:${day}`;
        const used = parseInt((await env.SUB_CACHE.get(key)) ?? '0', 10) || 0;
        if (used >= DAILY_MESSAGE_LIMIT) {
          console.log('daily_quota_exceeded', { key, used });
          return jsonError(429, 'rate_limited');
        }
        await env.SUB_CACHE.put(key, String(used + 1), { expirationTtl: 172_800 });
      }

      return await proxyChat(body, env);
    } catch (err) {
      console.log('worker_unhandled_error', {
        detail: err instanceof Error ? err.message : String(err),
      });
      return jsonError(500, 'internal_error');
    }
  },
} satisfies ExportedHandler<Env>;

function validate(body: ChatRequest): Response | null {
  if (!body.signedTransaction || typeof body.signedTransaction !== 'string') {
    return jsonError(400, 'missing_signed_transaction');
  }
  if (!Array.isArray(body.messages) || body.messages.length === 0) {
    return jsonError(400, 'missing_messages');
  }
  if (body.messages.length > MAX_MESSAGES) {
    return jsonError(400, 'too_many_messages');
  }
  let totalChars = 0;
  for (const m of body.messages) {
    if (!m || !ALLOWED_ROLES.has(m.role) || typeof m.content !== 'string') {
      return jsonError(400, 'bad_message_shape');
    }
    if (m.content.length > MAX_MESSAGE_CHARS) {
      return jsonError(400, 'message_too_long');
    }
    totalChars += m.content.length;
  }
  if (totalChars > MAX_TOTAL_CHARS) {
    return jsonError(400, 'payload_too_large');
  }
  return null;
}

function jsonError(status: number, reason: string): Response {
  return new Response(JSON.stringify({ error: reason }), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}
