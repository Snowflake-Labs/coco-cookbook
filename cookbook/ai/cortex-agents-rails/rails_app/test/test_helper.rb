ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Stands in for SNOWFLAKE_AGENT: replays canned SSE events, records what it was asked.
class FakeAgent
  attr_reader :calls

  def initialize(events) = (@events = events; @calls = [])

  def stream(text, **opts)
    @calls << [text, opts]
    @events.each { |event, data| yield event, data }
  end
end
