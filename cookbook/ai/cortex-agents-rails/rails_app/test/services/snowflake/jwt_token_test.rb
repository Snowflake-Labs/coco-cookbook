require "test_helper"

class Snowflake::JwtTokenTest < ActiveSupport::TestCase
  KEY = OpenSSL::PKey::RSA.new(2048)

  def token(account: "myorg-myacct")
    Snowflake::JwtToken.new(account: account, user: "rails_agent_svc", private_key_pem: KEY.to_pem)
  end

  def claims(jwt) = JWT.decode(jwt.to_s, KEY.public_key, true, algorithm: "RS256").first

  test "signs iss and sub with the uppercased account, user, and key fingerprint" do
    fp = "SHA256:" + Base64.strict_encode64(Digest::SHA256.digest(KEY.public_key.to_der))
    c = claims(token)
    assert_equal "MYORG-MYACCT.RAILS_AGENT_SVC", c["sub"]
    assert_equal "MYORG-MYACCT.RAILS_AGENT_SVC.#{fp}", c["iss"]
  end

  test "drops a region suffix from the account" do
    assert_equal "XY12345.RAILS_AGENT_SVC", claims(token(account: "xy12345.us-east-1"))["sub"]
  end

  test "expires in under an hour" do
    c = claims(token)
    assert_operator c["exp"] - c["iat"], :<, 3600
  end

  test "reuses the token until a minute before expiry, then refreshes" do
    t = token
    first = t.to_s
    assert_equal first, t.to_s
    travel(58.minutes + 30.seconds) do
      refute_equal first, t.to_s
    end
  end
end
