# frozen_string_literal: true

require "rails_helper"

RSpec.describe JsonWebToken do
  let(:payload) { { user_id: 1, email: "test@example.com", role: "patient" } }

  before do
    # Ensure JWT_SECRET is set for tests
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("JWT_SECRET").and_return("test_secret_key")
  end

  describe ".encode" do
    it "encodes a payload into a JWT token" do
      token = described_class.encode(payload)

      expect(token).to be_a(String)
      expect(token.split(".").length).to eq(3) # JWT has 3 parts
    end

    it "includes expiration time in the token" do
      token = described_class.encode(payload)
      decoded = JWT.decode(token, "test_secret_key", true, algorithm: "HS256").first

      expect(decoded["exp"]).to be_present
      expect(decoded["exp"]).to be > Time.current.to_i
    end

    it "includes issued at time in the token" do
      token = described_class.encode(payload)
      decoded = JWT.decode(token, "test_secret_key", true, algorithm: "HS256").first

      expect(decoded["iat"]).to be_present
      expect(decoded["iat"]).to be <= Time.current.to_i
    end

    it "includes a unique token identifier (jti)" do
      token = described_class.encode(payload)
      decoded = JWT.decode(token, "test_secret_key", true, algorithm: "HS256").first

      expect(decoded["jti"]).to be_present
      expect(decoded["jti"]).to match(/\A[a-f0-9-]+\z/)
    end

    it "sets token type to access" do
      token = described_class.encode(payload)
      decoded = JWT.decode(token, "test_secret_key", true, algorithm: "HS256").first

      expect(decoded["type"]).to eq("access")
    end

    it "accepts custom expiration time" do
      freeze_time = Time.current
      allow(Time).to receive(:current).and_return(freeze_time)

      token = described_class.encode(payload, expiration: 1.hour)
      decoded = JWT.decode(token, "test_secret_key", true, algorithm: "HS256").first

      expected_exp = (freeze_time + 1.hour).to_i
      expect(decoded["exp"]).to eq(expected_exp)
    end
  end

  describe ".encode_refresh_token" do
    it "encodes a refresh token with longer expiration" do
      token = described_class.encode_refresh_token(user_id: 1)
      decoded = JWT.decode(token, "test_secret_key", true, algorithm: "HS256").first

      # Refresh tokens should expire in 7 days by default
      expect(decoded["exp"]).to be > (Time.current + 6.days).to_i
    end

    it "sets token type to refresh" do
      token = described_class.encode_refresh_token(user_id: 1)
      decoded = JWT.decode(token, "test_secret_key", true, algorithm: "HS256").first

      expect(decoded["type"]).to eq("refresh")
    end
  end

  describe ".decode" do
    it "decodes a valid token and returns the payload" do
      token = described_class.encode(payload)
      decoded = described_class.decode(token)

      expect(decoded[:user_id]).to eq(1)
      expect(decoded[:email]).to eq("test@example.com")
      expect(decoded[:role]).to eq("patient")
    end

    it "returns a hash with indifferent access" do
      token = described_class.encode(payload)
      decoded = described_class.decode(token)

      expect(decoded["user_id"]).to eq(1)
      expect(decoded[:user_id]).to eq(1)
    end

    it "raises ExpiredTokenError for expired tokens" do
      token = described_class.encode(payload, expiration: -1.hour)

      expect { described_class.decode(token) }
        .to raise_error(JsonWebToken::ExpiredTokenError, "Token has expired")
    end

    it "raises InvalidTokenError for malformed tokens" do
      expect { described_class.decode("invalid.token.here") }
        .to raise_error(JsonWebToken::InvalidTokenError)
    end

    it "raises InvalidTokenError for tokens with wrong signature" do
      token = JWT.encode(payload, "wrong_secret", "HS256")

      expect { described_class.decode(token) }
        .to raise_error(JsonWebToken::InvalidTokenError)
    end

    it "raises InvalidTokenError for tokens missing required fields" do
      # Create a token without the required fields
      incomplete_payload = { user_id: 1 }
      token = JWT.encode(incomplete_payload, "test_secret_key", "HS256")

      expect { described_class.decode(token) }
        .to raise_error(JsonWebToken::InvalidTokenError, /Missing required fields/)
    end
  end

  describe ".valid?" do
    it "returns true for valid tokens" do
      token = described_class.encode(payload)

      expect(described_class.valid?(token)).to be true
    end

    it "returns false for expired tokens" do
      token = described_class.encode(payload, expiration: -1.hour)

      expect(described_class.valid?(token)).to be false
    end

    it "returns false for invalid tokens" do
      expect(described_class.valid?("invalid.token")).to be false
    end
  end

  describe ".revoke" do
    context "with Redis available" do
      before do
        allow(described_class).to receive(:redis_available?).and_return(true)
      end

      it "revokes a valid token" do
        token = described_class.encode(payload)

        expect(described_class.revoke(token)).to be true
      end

      it "returns false for already invalid tokens" do
        expect(described_class.revoke("invalid.token")).to be false
      end
    end

    context "without Redis" do
      before do
        allow(described_class).to receive(:redis_available?).and_return(false)
      end

      it "still returns true for valid tokens" do
        token = described_class.encode(payload)

        expect(described_class.revoke(token)).to be true
      end
    end
  end

  describe ".expiring_soon?" do
    it "returns true if token expires within threshold" do
      token = described_class.encode(payload, expiration: 2.minutes)

      expect(described_class.expiring_soon?(token, threshold: 5.minutes)).to be true
    end

    it "returns false if token has plenty of time left" do
      token = described_class.encode(payload, expiration: 1.hour)

      expect(described_class.expiring_soon?(token, threshold: 5.minutes)).to be false
    end

    it "returns true for expired tokens" do
      token = described_class.encode(payload, expiration: -1.hour)

      expect(described_class.expiring_soon?(token, threshold: 5.minutes)).to be true
    end
  end
end
