/**
 * Minimal Cloudflare Worker proxy for the GDZ chat tab.
 *
 * Purpose:
 * - Keeps the LLM API key off the static website.
 * - Accepts { messages: [{role, content}, ...] } from the Flutter web app.
 * - Calls an OpenAI-compatible /chat/completions endpoint.
 * - Returns { reply: "..." }.
 *
 * Deploy (Cloudflare Dashboard -> Workers):
 * 1. Create a Worker and paste this file.
 * 2. Add secrets/vars:
 *    - OPENAI_API_KEY   (required)
 *    - OPENAI_BASE_URL  (optional, default: https://api.openai.com/v1)
 *    - OPENAI_MODEL     (optional, default: gpt-4o-mini)
 *    - ALLOWED_ORIGIN   (optional, e.g. https://segofi566.github.io)
 * 3. Deploy and copy the Worker URL, e.g. https://gdz-chat.example.workers.dev
 * 4. Build the web app with:
 *    flutter build web --dart-define=CHAT_API_URL=https://gdz-chat.example.workers.dev
 *
 * Notes:
 * - Do NOT put OPENAI_API_KEY in Flutter/web code.
 * - Restrict ALLOWED_ORIGIN in production.
 */

export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin') || '*';
    const allowed = env.ALLOWED_ORIGIN || '*';
    const corsOrigin = allowed === '*' ? '*' : (origin === allowed ? allowed : allowed);

    const corsHeaders = {
      'Access-Control-Allow-Origin': corsOrigin,
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Accept',
      'Access-Control-Max-Age': '86400',
      'Vary': 'Origin',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    if (request.method !== 'POST') {
      return json({ error: 'Method not allowed' }, 405, corsHeaders);
    }

    if (!env.OPENAI_API_KEY) {
      return json({ error: 'OPENAI_API_KEY is not configured' }, 500, corsHeaders);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: 'Invalid JSON body' }, 400, corsHeaders);
    }

    const messages = Array.isArray(body?.messages) ? body.messages : null;
    if (!messages || messages.length === 0) {
      return json({ error: 'messages array is required' }, 400, corsHeaders);
    }

    // Keep only simple role/content messages; cap history to limit cost.
    const safeMessages = messages
      .filter((m) => m && typeof m.role === 'string' && typeof m.content === 'string')
      .slice(-20)
      .map((m) => ({ role: m.role, content: m.content.slice(0, 4000) }));

    const baseUrl = (env.OPENAI_BASE_URL || 'https://api.openai.com/v1').replace(/\/$/, '');
    const model = env.OPENAI_MODEL || 'gpt-4o-mini';

    let upstream;
    try {
      upstream = await fetch(`${baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
        },
        body: JSON.stringify({
          model,
          messages: safeMessages,
          temperature: 0.4,
        }),
      });
    } catch (e) {
      return json({ error: 'Upstream request failed', detail: String(e) }, 502, corsHeaders);
    }

    const text = await upstream.text();
    let data;
    try {
      data = JSON.parse(text);
    } catch {
      return json({ error: 'Upstream returned invalid JSON' }, 502, corsHeaders);
    }

    if (!upstream.ok) {
      return json(
        { error: 'Upstream error', status: upstream.status, detail: data?.error?.message || data?.error || text.slice(0, 300) },
        upstream.status,
        corsHeaders,
      );
    }

    const reply = data?.choices?.[0]?.message?.content;
    if (typeof reply !== 'string' || !reply.trim()) {
      return json({ error: 'Empty upstream reply' }, 502, corsHeaders);
    }

    return json({ reply }, 200, corsHeaders);
  },
};

function json(obj, status, headers) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', ...headers },
  });
}
