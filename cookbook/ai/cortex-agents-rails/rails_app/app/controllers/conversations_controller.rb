class ConversationsController < ApplicationController
  # Every page load starts a new Snowflake thread.
  def new
    @conversation = Conversation.create!(thread_id: SNOWFLAKE_AGENT.create_thread(app: "rails-cookbook"))
    # The signed, encrypted session cookie is the only way back to it: no IDs in the page.
    session[:conversation_id] = @conversation.id
  end
end
