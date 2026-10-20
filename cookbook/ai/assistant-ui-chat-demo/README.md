# assistant-ui Chat Demo

A **Vite + React** chat app powered by [`cortex-code-agent-sdk`](https://www.npmjs.com/package/cortex-code-agent-sdk), rendered with [`assistant-ui`](https://www.assistant-ui.com/) primitives.

The entire backend runs as a Vite plugin — no separate server process. A custom `ChatModelAdapter` streams NDJSON from `/api/chat` and drives the thread with tool cards, SQL highlighting, result tables, a live progress indicator, and per-tool permission prompts.

## Files

| Path | Description |
|------|-------------|
| `vite.config.ts` | Vite dev server + `cortex-api` plugin (Express middleware for `/api/chat` and `/api/permission/:id`) |
| `src/server/cortexAgent.ts` | SDK logic: `runAgent()`, `AgentEvent` type, ANSI stripping |
| `src/context/AgentContext.tsx` | React state: permissions, progress, plan mode toggle, `ChatModelAdapter` |
| `src/thread/Thread.tsx` | Thread layout, messages, composer |
| `src/thread/ToolCard.tsx` | Tool card, result table, permission prompt, icons |
| `src/thread/ProgressIndicator.tsx` | Animated dots + live stderr/thinking text |
| `src/thread/highlighter.ts` | Shared PrismLight SQL syntax highlighter |
| `src/App.tsx` | App root — header with plan mode toggle |
| `src/theme.css` | Design tokens (light + dark mode) |

## Prerequisites

- Node.js ≥ 20
- CoCo CLI on `PATH`:
  ```bash
  curl -LsS https://ai.snowflake.com/static/cc-scripts/install.sh | CORTEX_CHANNEL=beta sh
  ```
- A Snowflake CLI connection (`~/.snowflake/connections.toml`). Set the connection name:
  ```bash
  export SNOWFLAKE_CONNECTION=my_connection
  ```

## Run

```bash
npm install
npm run dev
```

Opens at **http://localhost:5173**. One process — no separate API server.

## How it works

### Architecture

```
Browser → Vite dev server (port 5173)
              ├── /api/chat        POST  →  runAgent() streams NDJSON
              └── /api/permission/:id  POST  →  resolves pending canUseTool promise
```

The API routes live in `vite.config.ts` as a `configureServer` plugin — Express middleware mounted directly on Vite's Connect server. No proxy, no separate port, no timeout issues.

### Permission flow

1. Agent wants to run a tool → SDK calls `canUseTool`
2. Server writes `permission-request` event to the NDJSON stream
3. Client renders the **allow / deny** prompt in the tool card
4. User clicks allow → `POST /api/permission/:id` → `canUseTool` resolves → tool runs
5. Server writes `permission-resolved` → badge updates to `✓ allowed`

### Plan mode

Toggle **plan** in the header to run the agent with `permissionMode: "plan"`. The agent describes what it would do without executing any tools.

### Progress indicator

`stderr` from the CLI is stripped of ANSI codes and surfaced as a live status line below the messages while the agent is running. Thinking blocks (if any) are similarly surfaced.

## Known limitations

- **Delta streaming** (`includePartialMessages`) was prototyped but disabled — rapid NDJSON writes cause backpressure issues that drop the connection. A future implementation could use SSE or WebSockets instead of NDJSON for the streaming layer.
- Each user turn spawns a fresh `query()` call — there is no persistent session across turns. To add memory, swap `query()` for `createCortexCodeSession()` keyed by a session ID.
