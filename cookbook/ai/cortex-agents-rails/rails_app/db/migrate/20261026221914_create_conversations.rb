class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.bigint :thread_id, null: false # Snowflake IDs are int64
      t.bigint :last_assistant_message_id

      t.timestamps
    end
  end
end
