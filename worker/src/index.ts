import type { Env, ChatRequest } from './types';
import { verifySignedTransaction } from './verify';
import { proxyChat } from './fireworks';

const MAX_MESSAGES = 40;
const ALLOWED_ROLES = new Set<string>(['user', 'assistant']);

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
  for (const m of body.messages) {
    if (!m || !ALLOWED_ROLES.has(m.role) || typeof m.content !== 'string') {
      return jsonError(400, 'bad_message_shape');
    }
  }
  return null;
}

function jsonError(status: number, reason: string): Response {
  return new Response(JSON.stringify({ error: reason }), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}
