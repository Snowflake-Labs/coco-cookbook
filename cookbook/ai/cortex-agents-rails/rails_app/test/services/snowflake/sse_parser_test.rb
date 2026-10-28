require "test_helper"

class Snowflake::SseParserTest < ActiveSupport::TestCase
  setup do
    @events = []
    @parser = Snowflake::SseParser.new { |event, data| @events << [event, data] }
  end

  test "parses a complete event" do
    @parser << "event: response.text.delta\ndata: {\"text\":\"Hi\"}\n\n"
    assert_equal [["response.text.delta", { "text" => "Hi" }]], @events
  end

  test "buffers an event split across chunks" do
    @parser << "event: response.text.delta\nda"
    assert_empty @events
    @parser << "ta: {\"text\":\"Hi\"}\n"
    assert_empty @events
    @parser << "\n"
    assert_equal 1, @events.size
  end

  test "handles CRLF line endings" do
    @parser << "event: response.status\r\ndata: {\"message\":\"Planning\"}\r\n\r\n"
    assert_equal [["response.status", { "message" => "Planning" }]], @events
  end

  test "parses several events in one chunk" do
    @parser << "event: a\ndata: {\"n\":1}\n\nevent: b\ndata: {\"n\":2}\n\n"
    assert_equal %w[a b], @events.map(&:first)
  end

  test "joins multi-line data fields" do
    @parser << "event: a\ndata: {\"n\":\ndata: 1}\n\n"
    assert_equal [["a", { "n" => 1 }]], @events
  end

  test "defaults the event name to message" do
    @parser << "data: {\"n\":1}\n\n"
    assert_equal "message", @events.first.first
  end

  test "skips the [DONE] terminator and data-less blocks" do
    @parser << "event: done\ndata: [DONE]\n\n: keep-alive comment\n\n"
    assert_empty @events
  end
end
