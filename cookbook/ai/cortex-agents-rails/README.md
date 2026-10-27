# Cortex Agents + Ruby on Rails

Call a Snowflake Cortex Agent from a Rails app using the `agent:run` REST API. Answers stream to the browser token by token, and multi-turn context is kept in Snowflake threads. Use CoCo to build it.

There's no official Ruby SDK for Cortex Agents; the Agent SDK ships in TypeScript and Python. This recipe shows that you don't need one: Faraday, the `jwt` gem, and about 100 lines of Ruby cover auth, streaming, threads, and background runs.

> **Already using `rb-snowflake-client`?** Keep it for SQL. It wraps the SQL API (`/api/v2/statements`), so it can't call `agent:run` or stream agent events. Use it with `SNOWFLAKE.CORTEX.DATA_AGENT_RUN(...)` only for batch jobs that don't need streaming.

## Files

| File | Description |
|---|---|
| `sample_data.sql` | Creates the `REVENUE` table (144 rows), a semantic view, the `REVENUE_AGENT` Cortex Agent, a least-privilege role, and a key-pair service user |
| `rails_app/` | Working Rails 8 app: JWT auth, agent client, SSE parser, streaming controller, and a chat page |
| `CHEATSHEET.md` | One-page reference covering endpoints, auth, streaming, threads, background runs, and a production checklist |

## Prerequisites

- A Snowflake account with Cortex Agents enabled, and a role that can create users, roles, and agents (for example `ACCOUNTADMIN`)
- Ruby 3.0+ (tested on Ruby 4.0.9, Rails 8.1.4). macOS's built-in Ruby 2.6 won't work: `brew install ruby`
- `openssl`

## Setup

1. Run `sample_data.sql` in your Snowflake account.

2. Create a key pair for the service user and register the public key:

   ```bash
   cd cookbook/ai/cortex-agents-rails
   openssl genrsa 2048 | openssl pkcs8 -topk8 -nocrypt -out rsa_key.p8
   openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
   grep -v -- "-----" rsa_key.pub | tr -d '\n'   # paste this into the statement below
   ```

   ```sql
   ALTER USER RAILS_AGENT_SVC SET RSA_PUBLIC_KEY = '<paste here>';
   ```

3. Configure and run the app:

   ```bash
   cd rails_app
   cp .env.example .env            # fill in SNOWFLAKE_URL and SNOWFLAKE_ACCOUNT
   bundle install
   set -a && source .env && set +a
   bin/rails db:migrate
   bin/rails server
   ```

4. Open http://localhost:3000 and ask "Which product tier is the most profitable?", then follow up with "Which region drove most of that tier's profit?"

`SNOWFLAKE_ACCOUNT` uses the `<ORG>-<ACCOUNT>` form, for example `MYORG-MYACCOUNT`. Run `SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME();` to get it.

To run the tests, use `bin/rails test`. They use a fake agent and Faraday's test adapter, so they don't need Snowflake credentials. They cover SSE parsing, the JWT claims and refresh, the request shape, HTTP errors, and the streaming controller.

## Prompt for CoCo

To build the app yourself instead of using `rails_app/`, run `sample_data.sql` and step 2 above, then paste this into CoCo from an empty folder:

```
Build a Ruby on Rails 8 app that chats with my Snowflake Cortex Agent
CORTEX_COOKBOOK.AI.REVENUE_AGENT through the Cortex Agents REST API.

Requirements:
1. No Snowflake gem. Use Faraday and the jwt gem.
2. Authenticate as service user RAILS_AGENT_SVC with key-pair JWT
   (private key at ../rsa_key.p8). Claims: iss = ACCOUNT.USER.SHA256:<fingerprint>,
   sub = ACCOUNT.USER, exp <= 1 hour. Send the header
   X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT. Cache the token and
   refresh it before it expires, thread-safely.
3. Create a thread with POST /api/v2/cortex/threads, then call
   POST /api/v2/databases/CORTEX_COOKBOOK/schemas/AI/agents/REVENUE_AGENT:run
   with thread_id and parent_message_id. Save metadata.assistant_message_id
   from the final "response" event in a Conversation model (bigint columns)
   and use it as parent_message_id for the next turn.
4. Parse the server-sent events stream incrementally. Skip the "data: [DONE]"
   terminator and ignore unknown event types.
5. Relay response.text.delta events to the browser with
   ActionController::Live. The Snowflake token must never reach the browser.
6. Add a single chat page that POSTs with fetch() and reads the streamed body.
7. Put each class in its own file so `bin/rails zeitwerk:check` passes.

Run it, ask "Which product tier is the most profitable?" and a follow-up
"Which region drove most of that tier's profit?", and confirm the follow-up
uses the context of the first answer.
```

## What You'll Learn

- How to authenticate to Snowflake REST APIs with a key-pair JWT from Ruby
- How to call `agent:run` against a saved agent object and parse its streamed events
- How to stream the answer to the browser with `ActionController::Live`
- How to render the agent's `response.chart` events (Vega-Lite specs from the `data_to_chart` tool) with vega-embed
- How to keep multi-turn context by storing `thread_id` and `parent_message_id`
- How to scope an external-facing agent with a least-privilege service user and an agent-level budget

## Expected Output

| Object | Type | Description |
|---|---|---|
| `CORTEX_COOKBOOK.AI.REVENUE` | Table | 144 rows of monthly 2024 revenue data |
| `CORTEX_COOKBOOK.AI.REVENUE_SV` | Semantic view | Revenue, cost, units, and profit metrics by region and product |
| `CORTEX_COOKBOOK.AI.REVENUE_AGENT` | Cortex Agent | Cortex Analyst tool over the semantic view plus `data_to_chart`, 60s / 16K-token budget |
| `RAILS_AGENT_ROLE` / `RAILS_AGENT_SVC` | Role / service user | The only identity the Rails app uses |
| Rails app | Web app | Chat page that streams answers. Example: "The Enterprise tier is the most profitable. It made $1.64M in profit in 2024 at a 60% margin." |

## Gotchas

- The stream ends with `event: done` / `data: [DONE]`, which isn't JSON. Skip it in your parser.
- Background runs (`background: true`) return `run_id` under `metadata`, not at the top level.
- Thread and message IDs are int64. Use `bigint` columns.
- `EventSource` only supports GET, so read the POST response body with `fetch()` instead.
- Chart specs come with a fixed width. Set `width: "container"` to make them responsive.
- Snowflake dates in chart data are midnight UTC. Use a `utc` time unit on the x-axis, or every month shifts back by one in US time zones.
- Each `ActionController::Live` request holds a Puma thread for the whole answer, so size Puma accordingly or use background runs.

## Cleanup

```sql
DROP USER IF EXISTS RAILS_AGENT_SVC;
DROP ROLE IF EXISTS RAILS_AGENT_ROLE;
DROP AGENT IF EXISTS CORTEX_COOKBOOK.AI.REVENUE_AGENT;
DROP SEMANTIC VIEW IF EXISTS CORTEX_COOKBOOK.AI.REVENUE_SV;
```
