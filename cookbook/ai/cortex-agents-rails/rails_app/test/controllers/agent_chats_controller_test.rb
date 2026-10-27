require "test_helper"

class AgentChatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @convo = open_chat
    @convo.update!(last_assistant_message_id: 222)
  end

  # Loading the chat page is what puts a conversation in this browser's session.
  def open_chat
    agent = FakeAgent.new([])
    agent.define_singleton_method(:create_thread) { |**| 111 }
    Object.const_set(:SNOWFLAKE_AGENT, agent)
    get root_path
    Object.send(:remove_const, :SNOWFLAKE_AGENT)
    Conversation.last
  end

  teardown { Object.send(:remove_const, :SNOWFLAKE_AGENT) if defined?(SNOWFLAKE_AGENT) }

  def with_agent(events)
    agent = FakeAgent.new(events)
    Object.const_set(:SNOWFLAKE_AGENT, agent)
    agent
  end

  # [[event, data], ...] from the SSE response body
  def sse_events
    response.body.split("\n\n").filter_map do |block|
      data = block[/^data: (.*)$/, 1] or next
      [block[/^event: (.*)$/, 1], JSON.parse(data)]
    end
  end

  test "relays deltas, status, and charts, then saves the next parent_message_id" do
    agent = with_agent([
      ["response.status", { "message" => "Planning the next steps" }],
      ["response.text.delta", { "text" => "North " }],
      ["response.chart", { "chart_spec" => "{\"mark\":\"line\"}" }],
      ["response.suggested_queries", { "suggested_queries" => [] }],
      ["response", { "metadata" => { "assistant_message_id" => 333 } }]
    ])

    post agent_chats_path, params: { message: "Chart revenue" }

    assert_equal "text/event-stream", response.media_type
    assert_equal [["Chart revenue", { thread_id: 111, parent_message_id: 222 }]], agent.calls
    assert_equal [
      ["status", { "status" => "Planning the next steps" }],
      ["delta", { "text" => "North " }],
      ["chart", { "spec" => "{\"mark\":\"line\"}" }],
      ["done", {}]
    ], sse_events
    assert_equal 333, @convo.reload.last_assistant_message_id
  end

  test "starts a new thread with parent_message_id 0" do
    @convo.update!(last_assistant_message_id: nil)
    agent = with_agent([])
    post agent_chats_path, params: { message: "hi" }
    assert_equal 0, agent.calls.first.last[:parent_message_id]
  end

  test "passes agent errors through" do
    with_agent([["error", { "message" => "budget exceeded" }]])
    post agent_chats_path, params: { message: "hi" }
    assert_equal [["error", { "message" => "budget exceeded" }]], sse_events
  end

  test "ignores a conversation_id from params and uses the session's conversation" do
    victim = Conversation.create!(thread_id: 999, last_assistant_message_id: 888)
    agent = with_agent([])
    post agent_chats_path, params: { conversation_id: victim.id, message: "hi" }
    assert_equal 111, agent.calls.first.last[:thread_id]
  end

  test "refuses to talk to the agent without a session conversation" do
    reset!
    agent = with_agent([])
    post agent_chats_path, params: { conversation_id: @convo.id, message: "hi" }
    assert_response :not_found
    assert_empty agent.calls
  end
end
