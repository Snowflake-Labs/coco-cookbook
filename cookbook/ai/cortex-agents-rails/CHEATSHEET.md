# Cortex Agents REST API + Ruby on Rails: Cheat Sheet

Call a Snowflake Cortex Agent from Rails using `agent:run`, stream the answer to the browser, and keep multi-turn threads. All of it runs server-side.

---

## 1. Pick your client (short answer)

| Option | Good for | Limitation |
|---|---|---|
| **Faraday (or Net::HTTP) + `jwt` gem** (recommended) | `agent:run` with SSE streaming, threads, background runs | You write a thin wrapper (~100 LOC, below) |
| `rinsed-org/rb-snowflake-client` | SQL workloads over the SQL API v2 | Wraps `/api/v2/statements` only. It does **not** call `agent:run` and does not stream agent events |
| `rb-snowflake-client` + `SNOWFLAKE.CORTEX.DATA_AGENT_RUN(...)` | Batch/offline jobs, no streaming needed | Returns one JSON blob. No token-by-token UX |

There is no official Ruby SDK. The Cortex Agent SDK ships in TypeScript and Python only. For Rails, a small Faraday-based client is the cleanest pattern. Keep `rb-snowflake-client` for the SQL side of your app; the two work fine together.

---

## 2. Endpoints you'll use

```
POST /api/v2/databases/{db}/schemas/{schema}/agents/{name}:run   # run a saved agent object (recommended)
POST /api/v2/cortex/agent:run                                    # inline agent (config in body)
POST /api/v2/cortex/threads                                      # create a conversation thread
GET  /api/v2/cortex/agent/runs/{run_id}?starting_after=N         # reconnect to a stream
POST /api/v2/cortex/agent/runs/{run_id}/cancel                   # cancel a run
```

Base URL: `https://<account_identifier>.snowflakecomputing.com`

> Use a **saved agent object** (`CREATE AGENT`) for an external-facing app. Models, instructions, and orchestration stay governed in Snowflake, and callers can't override them in the run request.

---

## 3. Auth: key-pair JWT for a service user

Requires Ruby 3.0+ (tested on Ruby 4.0.9, Rails 8.1.4, faraday 2.15, jwt 3.3).

```ruby
# Gemfile
gem "faraday"
gem "jwt"
```

```ruby
# app/services/snowflake/jwt_token.rb
require "openssl"
require "jwt"
require "digest"
require "base64"

module Snowflake
  class JwtToken
    LIFETIME = 59 * 60 # Snowflake max is 1 hour

    def initialize(account:, user:, private_key_pem:, passphrase: nil)
      @account = account.upcase.split(".").first # account locator / org-acct, no region
      @user    = user.upcase
      @key     = OpenSSL::PKey::RSA.new(private_key_pem, passphrase)
      @mutex   = Mutex.new
    end

    def to_s
      @mutex.synchronize do
        refresh! if @token.nil? || Time.now.to_i > @exp - 60
        @token
      end
    end

    private

    def refresh!
      now  = Time.now.to_i
      @exp = now + LIFETIME
      fp   = "SHA256:" + Base64.strict_encode64(Digest::SHA256.digest(@key.public_key.to_der))
      payload = { iss: "#{@account}.#{@user}.#{fp}", sub: "#{@account}.#{@user}", iat: now, exp: @exp }
      @token = JWT.encode(payload, @key, "RS256")
    end
  end
end
```

Headers on every call:

```
Authorization: Bearer <jwt>
X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT
Content-Type: application/json
Accept: text/event-stream      # or application/json with "stream": false
```

Other auth options: a programmatic access token (PAT) for prototypes, or OAuth when you need per-end-user identity.

---

## 4. The client (~60 LOC)

```ruby
# app/services/snowflake/agent_client.rb
require "faraday"
require "json"

module Snowflake
  class AgentClient
    def initialize(base_url:, token:, database:, schema:, agent:)
      @token = token
      @path  = "/api/v2/databases/#{database}/schemas/#{schema}/agents/#{agent}:run"
      @http  = Faraday.new(url: base_url) do |f|
        f.options.timeout      = 900 # agent:run sync timeout is 15 min
        f.options.open_timeout = 10
      end
    end

    def create_thread(app: "rails-app")
      res = @http.post("/api/v2/cortex/threads", { origin_application: app }.to_json, headers)
      JSON.parse(res.body).fetch("thread_id")
    end

    # Non-streaming: one JSON response (same shape as the final `response` event)
    def ask(text, thread_id: nil, parent_message_id: 0)
      body = payload(text, thread_id, parent_message_id).merge(stream: false)
      res  = @http.post(@path, body.to_json, headers("application/json"))
      raise "Agent error #{res.status}: #{res.body}" unless res.success?
      JSON.parse(res.body)
    end

    # Streaming: yields (event_name, data_hash) for each SSE event
    def stream(text, thread_id: nil, parent_message_id: 0, &block)
      body   = payload(text, thread_id, parent_message_id)
      parser = SseParser.new(&block)
      error  = +""
      res = @http.post(@path, body.to_json, headers("text/event-stream")) do |req|
        # An HTTP error body (e.g. 401 bad JWT) is JSON, not SSE: keep it for the exception.
        req.options.on_data = ->(chunk, _bytes, env) { env.status.to_i >= 400 ? error << chunk : parser << chunk }
      end
      raise "Agent error #{res.status}: #{error}" unless res.success?
    end

    private

    def payload(text, thread_id, parent_message_id)
      msg = { role: "user", content: [{ type: "text", text: text }] }
      body = { messages: [msg] }
      body.merge!(thread_id: thread_id, parent_message_id: parent_message_id) if thread_id
      body
    end

    def headers(accept = "application/json")
      {
        "Authorization" => "Bearer #{@token}",
        "X-Snowflake-Authorization-Token-Type" => "KEYPAIR_JWT",
        "Content-Type" => "application/json",
        "Accept" => accept
      }
    end
  end
end
```

```ruby
# app/services/snowflake/sse_parser.rb  (own file so Zeitwerk autoloads it)
require "json"

module Snowflake
  # Minimal SSE parser: buffers chunks, splits on blank lines
  class SseParser
    def initialize(&on_event) = (@buf = +""; @on_event = on_event)

    def <<(chunk)
      @buf << chunk.delete("\r")
      while (idx = @buf.index("\n\n"))
        raw = @buf.slice!(0, idx + 2)
        event = raw[/^event: ?(.*)$/, 1] || "message"
        data  = raw.scan(/^data: ?(.*)$/).flatten.join("\n")
        next if data.empty? || data == "[DONE]" # stream terminator, not JSON
        @on_event.call(event, JSON.parse(data))
      end
    end
  end
end
```

```ruby
# config/initializers/snowflake_agent.rb
SNOWFLAKE_AGENT = Snowflake::AgentClient.new(
  base_url: ENV.fetch("SNOWFLAKE_URL"),
  token: Snowflake::JwtToken.new(
    account: ENV.fetch("SNOWFLAKE_ACCOUNT"),
    user: ENV.fetch("SNOWFLAKE_USER"),
    private_key_pem: Rails.application.credentials.snowflake_private_key
  ),
  database: "MY_DB", schema: "AGENTS", agent: "SUPPORT_AGENT"
)
```

The `JwtToken` object refreshes itself; string interpolation calls `to_s` on each request.

---

## 5. Stream it to the browser (`ActionController::Live`)

```ruby
# app/controllers/agent_chats_controller.rb
class AgentChatsController < ApplicationController
  include ActionController::Live

  def create
    response.headers["Content-Type"]      = "text/event-stream"
    response.headers["Cache-Control"]     = "no-cache"
    response.headers["X-Accel-Buffering"] = "no" # disable nginx buffering

    convo = current_user.conversations.find(params[:conversation_id])
    sse   = SSE.new(response.stream, retry: 3000)

    SNOWFLAKE_AGENT.stream(params.require(:message),
                           thread_id: convo.thread_id,
                           parent_message_id: convo.last_assistant_message_id || 0) do |event, data|
      case event
      when "response.text.delta" then sse.write({ text: data["text"] }, event: "delta")
      when "response.status"     then sse.write({ status: data["message"] }, event: "status")
      when "response.chart"      then sse.write({ spec: data["chart_spec"] }, event: "chart")
      when "response.table"      then sse.write(data["result_set"], event: "table")
      when "response"            # final, aggregated answer
        convo.update!(last_assistant_message_id: data.dig("metadata", "assistant_message_id"))
      when "error"               then sse.write(data, event: "error")
      else # ignore unknown events (e.g. response.suggested_queries, done): new ones get added
      end
    end
  ensure
    sse&.close
  end
end
```

Client side: use `fetch()` with a `ReadableStream` reader. `EventSource` only does GET, and you're POSTing. Or render deltas through Turbo Streams.

### Charts

Add the `data_to_chart` tool to the agent spec (`tools: [{ tool_spec: { type: "data_to_chart", name: "data_to_chart" } }]`) and the agent emits `response.chart`. Its `chart_spec` is a Vega-Lite JSON string, so render it with vega-embed:

```js
function renderChart(specJson, el) {
  // The agent's spec has a fixed size; make it fill the column instead.
  const spec = { ...JSON.parse(specJson), width: "container", autosize: { type: "fit", contains: "padding" } };
  // Snowflake dates arrive as midnight UTC; draw them in UTC so Jan 1 doesn't show as Dec 31 locally.
  const x = spec.encoding?.x;
  if (x?.type === "temporal") {
    x.title ??= x.field;
    x.timeUnit = "utc" + String(x.timeUnit || "yearmonthdate").replace(/^utc/, "");
  }
  vegaEmbed(el, spec, { actions: false });
}
```

---

## 6. Multi-turn threads (store two integers)

```ruby
# migration
add_column :conversations, :thread_id, :bigint
add_column :conversations, :last_assistant_message_id, :bigint
```

| Turn | `thread_id` | `parent_message_id` |
|---|---|---|
| First message | `create_thread` result | `0` |
| Follow-ups | same | `metadata.assistant_message_id` from the previous `response` event |

With threads, Snowflake keeps the history, so you send only the new user message.

---

## 7. Long-running work: background runs + ActiveJob

```ruby
body = { thread_id: tid, parent_message_id: pid, messages: [msg], background: true, stream: false }
# => { "status": "in_progress",
#      "metadata": { "thread_id": 4264, "run_id": "4264-83472", "user_message_id": 83472 } }
run_id = JSON.parse(res.body).dig("metadata", "run_id") # nested under metadata
```

- Kick it off in a Sidekiq/ActiveJob job, persist the `run_id`, and let the user leave the page.
- Reconnect with `GET /api/v2/cortex/agent/runs/{run_id}?starting_after=<last_seq>`. This works while the run is active and for 5 minutes after it finishes. After that you get `409`, so read the answer from the thread instead.
- Cancel with `POST .../runs/{run_id}/cancel`.
- Background runs require threads and time out after 6 hours (sync runs time out after 15 minutes).

---

## 8. Production checklist for an external-facing agent

- **Proxy only.** Never ship a Snowflake token to the browser. Rails is the only caller.
- **Least-privilege service user/role.** Grant `USAGE` on the agent and only the semantic views, search services, and warehouse it needs.
- **Saved agent object.** Callers can't override models, instructions, or orchestration on `:run`.
- **Budget it.** Set `orchestration.budget` (`seconds`, `tokens`) in the agent spec to cap cost per question.
- **Tenant isolation.** Use row access policies on the underlying data, or Cortex Search `filter`, keyed to the tenant. Don't rely on prompt instructions for isolation.
- **Handle unknown SSE events** and `response.warning` (for example `399569` TOOL_NOT_ACCESSIBLE).
- **Retries.** Retry 429/5xx on non-streaming calls with backoff. Don't blindly replay a streaming POST; reconnect by `run_id`.
- **Puma.** Each `ActionController::Live` stream holds a thread for the whole answer, so size threads/workers accordingly, or offload to background runs.
- **Observability.** Log `metadata.run_id`, `request_id`, and `metadata.usage.tokens_consumed` per request.
- **Feedback.** `POST .../agents/{name}:feedback` with the `request_id` closes the quality loop.

---

## 9. Quick smoke test (curl)

```bash
curl -N -X POST "$SNOWFLAKE_URL/api/v2/databases/MY_DB/schemas/AGENTS/agents/SUPPORT_AGENT:run" \
  -H "Authorization: Bearer $JWT" \
  -H "X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT" \
  -H "Content-Type: application/json" -H "Accept: text/event-stream" \
  -d '{"messages":[{"role":"user","content":[{"type":"text","text":"Top 5 accounts by ARR?"}]}]}'
```

---

**Docs:** [Cortex Agents Run API](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-run) | [DATA_AGENT_RUN](https://docs.snowflake.com/en/sql-reference/functions/data_agent_run-snowflake-cortex) | [Key-pair auth for REST APIs](https://docs.snowflake.com/en/developer-guide/sql-api/authenticating)
