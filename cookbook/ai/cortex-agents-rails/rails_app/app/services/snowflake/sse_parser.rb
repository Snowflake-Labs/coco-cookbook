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
