class ConversationsController < ApplicationController
  # Every page load starts a new Snowflake thread.
  def new
    @conversation = Conversation.create!(thread_id: SNOWFLAKE_AGENT.create_thread(app: "rails-cookbook"))
  end
end
