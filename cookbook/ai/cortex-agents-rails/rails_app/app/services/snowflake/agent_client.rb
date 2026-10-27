# app/services/snowflake/agent_client.rb
require "faraday"
require "json"

module Snowflake
  class AgentClient
    class Error < StandardError; end

    def initialize(base_url:, token:, database:, schema:, agent:, adapter: Faraday.default_adapter)
      @token = token
      @path  = "/api/v2/databases/#{database}/schemas/#{schema}/agents/#{agent}:run"
      @http  = Faraday.new(url: base_url) do |f|
        f.options.timeout      = 900 # agent:run sync timeout is 15 min
        f.options.open_timeout = 10
        f.adapter(*adapter)
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
      raise Error, "Agent error #{res.status}: #{res.body}" unless res.success?
      JSON.parse(res.body)
    end

    # Streaming: yields (event_name, data_hash) for each SSE event
    def stream(text, thread_id: nil, parent_message_id: 0, &block)
      body   = payload(text, thread_id, parent_message_id)
      parser = SseParser.new(&block)
      error  = +""
      streamed = false
      res = @http.post(@path, body.to_json, headers("text/event-stream")) do |req|
        # An HTTP error body is JSON, not SSE: keep it for the exception instead of parsing it.
        req.options.on_data = lambda do |chunk, _bytes, env|
          streamed = true
          env.status.to_i >= 400 ? error << chunk : parser << chunk
        end
      end
      raise Error, "Agent error #{res.status}: #{error.presence || res.body}" unless res.success?
      parser << res.body.to_s unless streamed # adapter without streaming support
      res
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
