#!/usr/bin/env node
// peek-ai bridge: OpenAI-style /v1/chat/completions (streaming or not) backed by `claude -p`,
// so claude-code/* models run on the local Claude plan. Only listens on 127.0.0.1.
const http = require('node:http');
const os = require('node:os');
const readline = require('node:readline');
const { spawn } = require('node:child_process');

const PORT = Number(process.env.PEEK_BRIDGE_PORT || 8787);
const MODELS = ['claude-code/sonnet', 'claude-code/opus', 'claude-code/haiku'];

// OpenAI messages -> one stream-json user event for claude -p (+ system prompt)
function toClaude(messages) {
  const system = [];
  const content = [];
  for (const m of messages) {
    const parts = typeof m.content === 'string' ? [{ type: 'text', text: m.content }] : m.content || [];
    if (m.role === 'system') { system.push(parts.map(p => p.text || '').join('\n')); continue; }
    for (const p of parts) {
      if (p.type === 'text') content.push({ type: 'text', text: m.role === 'assistant' ? `[assistant]: ${p.text}` : p.text });
      else if (p.type === 'image_url') {
        const match = /^data:([^;]+);base64,(.+)$/s.exec(p.image_url?.url || '');
        if (!match) throw new Error('only data: URLs are supported for images');
        content.push({ type: 'image', source: { type: 'base64', media_type: match[1], data: match[2] } });
      }
    }
  }
  return { system: system.join('\n\n'), event: { type: 'user', message: { role: 'user', content } } };
}

function runClaude(model, { system, event }) {
  const args = ['-p', '--input-format', 'stream-json', '--output-format', 'stream-json', '--verbose',
    '--include-partial-messages', '--model', model, '--tools', '', '--setting-sources', '',
    '--strict-mcp-config', '--disable-slash-commands', '--no-session-persistence'];
  if (system) args.push('--system-prompt', system);
  // tmpdir so no project CLAUDE.md leaks into the prompt
  const child = spawn('claude', args, { cwd: os.tmpdir(), stdio: ['pipe', 'pipe', 'pipe'] });
  child.stdin.end(JSON.stringify(event) + '\n');
  let stderr = '';
  child.stderr.on('data', d => { stderr += d; });
  child.on('error', e => { stderr += e.message; });
  return { child, lines: readline.createInterface({ input: child.stdout }), stderr: () => stderr };
}

function usageOf(result) {
  const u = result.usage || {};
  const prompt = (u.input_tokens || 0) + (u.cache_read_input_tokens || 0) + (u.cache_creation_input_tokens || 0);
  return { prompt_tokens: prompt, completion_tokens: u.output_tokens || 0, total_tokens: prompt + (u.output_tokens || 0) };
}

function send(res, code, body) {
  res.writeHead(code, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

async function completions(req, res) {
  let body = '';
  for await (const chunk of req) body += chunk;
  let parsed, input;
  try {
    parsed = JSON.parse(body);
    if (!MODELS.includes(parsed.model)) throw new Error(`model must be one of ${MODELS.join(', ')}`);
    input = toClaude(parsed.messages || []);
  } catch (e) { return send(res, 400, { error: { message: e.message, code: 400 } }); }

  const { child, lines, stderr } = runClaude(parsed.model.slice('claude-code/'.length), input);
  res.on('close', () => child.kill());
  const id = `chatcmpl-${Date.now()}`;
  const chunk = (delta, finish = null, extra = {}) =>
    res.write(`data: ${JSON.stringify({ id, object: 'chat.completion.chunk', created: Math.floor(Date.now() / 1000),
      model: parsed.model, choices: [{ index: 0, delta, finish_reason: finish }], ...extra })}\n\n`);

  if (parsed.stream) {
    res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', Connection: 'keep-alive' });
    chunk({ role: 'assistant' });
  }
  for await (const line of lines) {
    let ev;
    try { ev = JSON.parse(line); } catch { continue; }
    if (parsed.stream && ev.type === 'stream_event' && ev.event?.delta?.type === 'text_delta') chunk({ content: ev.event.delta.text });
    if (ev.type !== 'result') continue;
    if (ev.is_error) {
      if (parsed.stream) { res.write(`data: ${JSON.stringify({ error: { message: ev.result } })}\n\n`); return res.end(); }
      return send(res, 502, { error: { message: ev.result || 'claude -p failed', code: 502 } });
    }
    if (parsed.stream) { chunk({}, 'stop', { usage: usageOf(ev) }); res.write('data: [DONE]\n\n'); return res.end(); }
    return send(res, 200, { id, object: 'chat.completion', created: Math.floor(Date.now() / 1000), model: parsed.model,
      choices: [{ index: 0, message: { role: 'assistant', content: ev.result }, finish_reason: 'stop' }], usage: usageOf(ev) });
  }
  // claude exited without a result event (not logged in, CLI missing, ...)
  const message = `claude -p exited without a result: ${stderr().trim() || 'no output'}`;
  if (parsed.stream) { res.write(`data: ${JSON.stringify({ error: { message } })}\n\n`); return res.end(); }
  send(res, 502, { error: { message, code: 502 } });
}

http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/v1/models')
    return send(res, 200, { object: 'list', data: MODELS.map(id => ({ id, object: 'model', owned_by: 'claude-code' })) });
  if (req.method === 'POST' && req.url === '/v1/chat/completions')
    return completions(req, res).catch(e => send(res, 500, { error: { message: e.message, code: 500 } }));
  send(res, 404, { error: { message: 'not found', code: 404 } });
}).listen(PORT, '127.0.0.1', () => console.log(`peek bridge on http://127.0.0.1:${PORT}/v1`));
