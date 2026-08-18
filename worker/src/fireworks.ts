import type { Env, ChatRequest } from './types';
import { SYSTEM_PROMPT } from './prompt';

const FIREWORKS_URL = 'https://api.fireworks.ai/inference/v1/chat/completions';
const DEFAULT_MODEL = 'accounts/fireworks/models/deepseek-v4-flash-0731';
const MAX_TOKENS = 1024;

/// Calls Fireworks' OpenAI-compatible chat completions API with streaming
/// and returns a `Response` whose body is an SSE stream the iOS client
/// can consume directly. We translate Fireworks' OpenAI-style event format
/// into a simpler `data: {"text":"…"}` frame per delta so the iOS service
/// can stay tiny.
export async function proxyChat(body: ChatRequest, env: Env): Promise<Response> {
  const model = env.FIREWORKS_MODEL ?? DEFAULT_MODEL;

  // Fireworks (OpenAI-compatible) expects the system prompt as the first
  // message with role "system".
  const messages = [
    { role: 'system' as const, content: SYSTEM_PROMPT },
    ...body.messages,
  ];

  const upstream = await fetch(FIREWORKS_URL, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${env.FIREWORKS_API_KEY}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model,
      max_tokens: MAX_TOKENS,
      stream: true,
      // DeepSeek V4 reasons at high effort by default and streams the chain-of-
      // thought in delta.reasoning_content, which the iOS client drops (it only
      // decodes delta.content) — so the user just watches the typing indicator for
      // seconds before any text appears. `reasoning_effort: 'low'` is ignored by
      // this model on Fireworks (measured: reasoning output went *up*); the
      // Anthropic-style `thinking` block is the knob that works. Time-to-first-
      // token: ~3-12 s -> ~0.9 s. With thinking off the whole max_tokens budget
      // goes to the answer, which also removes the truncated/empty-reply risk.
      // NOTE: this param is DeepSeek-specific. If FIREWORKS_MODEL is ever swapped
      // to a non-DeepSeek model, re-verify or remove it — and never send `thinking`
      // and `reasoning_effort` together, Fireworks rejects that.
      thinking: { type: 'disabled' },
      messages,
    }),
  });

  if (!upstream.ok || !upstream.body) {
    const text = upstream.body ? (await upstream.text()).slice(0, 500) : '';
    console.log('fireworks_error', { status: upstream.status, body: text });
    // Generic 502: don't leak Fireworks account details to clients, and don't
    // pass upstream statuses through as if they were the worker's own.
    return new Response(JSON.stringify({ error: 'upstream_error' }), {
      status: 502,
      headers: { 'content-type': 'application/json' },
    });
  }

  const transformed = upstream.body
    .pipeThrough(new TextDecoderStream())
    .pipeThrough(translateOpenAISSE());

  return new Response(transformed, {
    headers: {
      'content-type': 'text/event-stream',
      'cache-control': 'no-cache, no-transform',
      'x-accel-buffering': 'no',
    },
  });
}

/// Re-frames Fireworks' OpenAI-style SSE stream into `data: {"text":"…"}` lines.
function translateOpenAISSE(): TransformStream<string, Uint8Array> {
  const encoder = new TextEncoder();
  let buffer = '';
  let endedCleanly = false;

  return new TransformStream({
    transform(chunk, controller) {
      buffer += chunk;
      // SSE events are separated by blank lines.
      const events = buffer.split('\n\n');
      buffer = events.pop() ?? '';
      for (const event of events) {
        const dataLine = event
          .split('\n')
          .find((l) => l.startsWith('data: '))
          ?.slice('data: '.length);
        if (!dataLine) continue;
        if (dataLine === '[DONE]') {
          controller.enqueue(encoder.encode('data: [DONE]\n\n'));
          endedCleanly = true;
          continue;
        }

        let parsed: unknown;
        try {
          parsed = JSON.parse(dataLine);
        } catch {
          continue;
        }
        const evt = parsed as {
          choices?: { delta?: { content?: string } }[];
        };
        const text = evt.choices?.[0]?.delta?.content;
        if (typeof text === 'string' && text.length > 0) {
          controller.enqueue(encoder.encode(`data: ${JSON.stringify({ text })}\n\n`));
        }
      }
    },
    flush(controller) {
      if (!endedCleanly) {
        controller.enqueue(encoder.encode('data: [DONE]\n\n'));
      }
    },
  });
}
