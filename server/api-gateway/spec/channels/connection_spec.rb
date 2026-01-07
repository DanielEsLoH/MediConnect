# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:jwt_secret) { "test_secret_key" }
  let(:user_id) { 123 }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("JWT_SECRET", anything).and_return(jwt_secret)
  end

  def generate_token(payload, secret = jwt_secret)
    JWT.encode(payload, secret, "HS256")
  end

  describe "#connect" do
    context "with valid JWT token" do
      let(:token) { generate_token({ sub: user_id, exp: 1.hour.from_now.to_i }) }

      it "successfully connects" do
        connect "/cable?token=#{token}"
        expect(connection.current_user_id).to eq(user_id)
      end
    end

    context "with user_id in token payload" do
      let(:token) { generate_token({ user_id: user_id, exp: 1.hour.from_now.to_i }) }

      it "successfully connects using user_id" do
        connect "/cable?token=#{token}"
        expect(connection.current_user_id).to eq(user_id)
      end
    end

    context "without token" do
      it "rejects the connection" do
        expect { connect "/cable" }.to have_rejected_connection
      end
    end

    context "with invalid token" do
      let(:invalid_token) { "invalid.token.here" }

      it "rejects the connection" do
        expect { connect "/cable?token=#{invalid_token}" }.to have_rejected_connection
      end
    end

    context "with expired token" do
      let(:expired_token) { generate_token({ sub: user_id, exp: 1.hour.ago.to_i }) }

      it "rejects the connection" do
        expect { connect "/cable?token=#{expired_token}" }.to have_rejected_connection
      end
    end

    context "with token signed with wrong secret" do
      let(:wrong_secret_token) { generate_token({ sub: user_id, exp: 1.hour.from_now.to_i }, "wrong_secret") }

      it "rejects the connection" do
        expect { connect "/cable?token=#{wrong_secret_token}" }.to have_rejected_connection
      end
    end
  end
end