# One client per process. JwtToken refreshes itself before the 1-hour limit.
# In production, load the private key from Rails credentials or a secrets manager.
Rails.application.config.to_prepare do
  next if Rails.env.test? # tests swap in a fake client, no Snowflake credentials needed

  SNOWFLAKE_AGENT = Snowflake::AgentClient.new(
    base_url: ENV.fetch("SNOWFLAKE_URL"),
    token: Snowflake::JwtToken.new(
      account: ENV.fetch("SNOWFLAKE_ACCOUNT"),
      user: ENV.fetch("SNOWFLAKE_USER", "RAILS_AGENT_SVC"),
      private_key_pem: File.read(ENV.fetch("SNOWFLAKE_PRIVATE_KEY_PATH"))
    ),
    database: ENV.fetch("SNOWFLAKE_AGENT_DATABASE", "CORTEX_COOKBOOK"),
    schema: ENV.fetch("SNOWFLAKE_AGENT_SCHEMA", "AI"),
    agent: ENV.fetch("SNOWFLAKE_AGENT_NAME", "REVENUE_AGENT")
  )
end
