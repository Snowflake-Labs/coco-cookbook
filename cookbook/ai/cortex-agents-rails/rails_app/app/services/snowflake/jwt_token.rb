# app/services/snowflake/jwt_token.rb
require "openssl"
require "jwt"
require "digest"
require "base64"

module Snowflake
  class JwtToken
    LIFETIME = 59 * 60 # Snowflake max is 1 hour

    def initialize(account:, user:, private_key_pem:, passphrase: nil)
      @account = account.upcase.split(".").first # account locator / org-acct, no region
      @user    = user.upcase
      @key     = OpenSSL::PKey::RSA.new(private_key_pem, passphrase)
      @mutex   = Mutex.new
    end

    def to_s
      @mutex.synchronize do
        refresh! if @token.nil? || Time.now.to_i > @exp - 60
        @token
      end
    end

    private

    def refresh!
      now  = Time.now.to_i
      @exp = now + LIFETIME
      fp   = "SHA256:" + Base64.strict_encode64(Digest::SHA256.digest(@key.public_key.to_der))
      payload = { iss: "#{@account}.#{@user}.#{fp}", sub: "#{@account}.#{@user}", iat: now, exp: @exp }
      @token = JWT.encode(payload, @key, "RS256")
    end
  end
end
