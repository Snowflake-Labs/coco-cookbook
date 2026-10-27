# Proxies a user message to the Cortex Agent and relays the answer to the
# browser as server-sent events. The Snowflake token never leaves the server.
class AgentChatsController < ApplicationController
  include ActionController::Live

  def create
    response.headers["Content-Type"]      = "text/event-stream"
    response.headers["Cache-Control"]     = "no-cache"
    response.headers["X-Accel-Buffering"] = "no" # disable nginx buffering

    convo = Conversation.find(params[:conversation_id])
    sse   = SSE.new(response.stream, retry: 3000)

    SNOWFLAKE_AGENT.stream(params.require(:message),
                           thread_id: convo.thread_id,
                           parent_message_id: convo.last_assistant_message_id || 0) do |event, data|
      case event
      when "response.text.delta" then sse.write({ text: data["text"] }, event: "delta")
      when "response.status"     then sse.write({ status: data["message"] }, event: "status")
      when "response.table"      then sse.write(data["result_set"], event: "table")
      when "response.chart"      then sse.write({ spec: data["chart_spec"] }, event: "chart") # Vega-Lite JSON string
      when "response"            # final, aggregated answer
        convo.update!(last_assistant_message_id: data.dig("metadata", "assistant_message_id"))
        sse.write({}, event: "done")
      when "error"               then sse.write(data, event: "error")
      else # ignore unknown events (e.g. response.suggested_queries, done): new ones get added
      end
    end
  rescue ActionController::Live::ClientDisconnected
    # browser went away mid-answer; nothing to do
  ensure
    sse&.close
  end
end
