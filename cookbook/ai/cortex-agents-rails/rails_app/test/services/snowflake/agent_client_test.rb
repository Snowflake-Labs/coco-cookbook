require "test_helper"

class Snowflake::AgentClientTest < ActiveSupport::TestCase
  RUN_PATH = "/api/v2/databases/DB/schemas/SC/agents/AG:run"

  setup do
    @stubs  = Faraday::Adapter::Test::Stubs.new
    @client = Snowflake::AgentClient.new(base_url: "https://acct.snowflakecomputing.com", token: "tok",
                                         database: "DB", schema: "SC", agent: "AG",
                                         adapter: [:test, @stubs])
  end

  test "sends key-pair JWT auth headers" do
    @stubs.post(RUN_PATH) do |env|
      assert_equal "Bearer tok", env.request_headers["Authorization"]
      assert_equal "KEYPAIR_JWT", env.request_headers["X-Snowflake-Authorization-Token-Type"]
      [200, {}, "{}"]
    end
    @client.ask("hi")
    @stubs.verify_stubbed_calls
  end

  test "omits thread fields when there is no thread" do
    @stubs.post(RUN_PATH) do |env|
      body = JSON.parse(env.body)
      assert_equal [{ "role" => "user", "content" => [{ "type" => "text", "text" => "hi" }] }], body["messages"]
      refute body.key?("thread_id")
      [200, {}, "{}"]
    end
    @client.ask("hi")
  end

  test "sends thread_id and parent_message_id for follow-ups" do
    @stubs.post(RUN_PATH) do |env|
      body = JSON.parse(env.body)
      assert_equal [123, 456], body.values_at("thread_id", "parent_message_id")
      [200, {}, "{}"]
    end
    @client.ask("hi", thread_id: 123, parent_message_id: 456)
  end

  test "ask raises on an HTTP error" do
    @stubs.post(RUN_PATH) { [401, {}, "bad token"] }
    assert_raises(Snowflake::AgentClient::Error) { @client.ask("hi") }
  end

  test "create_thread returns the thread_id" do
    @stubs.post("/api/v2/cortex/threads") { [200, {}, { thread_id: 987 }.to_json] }
    assert_equal 987, @client.create_thread
  end

  test "stream yields parsed events" do
    sse = "event: response.text.delta\ndata: {\"text\":\"Hi\"}\n\nevent: done\ndata: [DONE]\n\n"
    @stubs.post(RUN_PATH) { [200, { "Content-Type" => "text/event-stream" }, sse] }
    events = []
    @client.stream("hi") { |e, d| events << [e, d] }
    assert_equal [["response.text.delta", { "text" => "Hi" }]], events
  end

  test "stream raises on an HTTP error instead of yielding nothing" do
    @stubs.post(RUN_PATH) { [401, {}, "{\"message\":\"JWT token is invalid.\"}"] }
    error = assert_raises(Snowflake::AgentClient::Error) { @client.stream("hi") { flunk "no events expected" } }
    assert_match "401", error.message
  end
end
