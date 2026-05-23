import type { Env, ChatRequest } from './types';
import { SYSTEM_PROMPT } from './prompt';

const FIREWORKS_URL = 'https://api.fireworks.ai/inference/v1/chat/completions';
const DEFAULT_MODEL = 'accounts/fireworks/models/gpt-oss-120b';
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
      messages,
    }),
  });

  if (!upstream.ok || !upstream.body) {
    const text = upstream.body ? (await upstream.text()).slice(0, 500) : '';
    console.log('fireworks_error', { status: upstream.status, body: text });
    return new Response(JSON.stringify({ error: 'upstream_error', detail: text }), {
      status: upstream.status === 200 ? 502 : upstream.status,
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
