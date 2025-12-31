# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuthenticationService do
  describe ".authenticate" do
    # Use let! to eagerly create the user before each test
    let!(:user) { create(:user, email: "test@example.com", password: "Password123") }

    context "with valid credentials" do
      it "returns the user" do
        result = described_class.authenticate("test@example.com", "Password123")
        expect(result).to eq(user)
      end

      it "is case insensitive for email" do
        result = described_class.authenticate("TEST@EXAMPLE.COM", "Password123")
        expect(result).to eq(user)
      end
    end

    context "with invalid email" do
      it "raises AuthenticationError" do
        expect do
          described_class.authenticate("wrong@example.com", "Password123")
        end.to raise_error(AuthenticationService::AuthenticationError, "Invalid email or password")
      end
    end

    context "with invalid password" do
      it "raises AuthenticationError" do
        expect do
          described_class.authenticate("test@example.com", "WrongPassword")
        end.to raise_error(AuthenticationService::AuthenticationError, "Invalid email or password")
      end
    end

    context "with inactive user" do
      let(:inactive_user) { create(:user, :inactive) }

      it "raises AuthenticationError" do
        expect do
          described_class.authenticate(inactive_user.email, "Password123")
        end.to raise_error(AuthenticationService::AuthenticationError)
      end
    end
  end

  describe ".register" do
    let(:valid_params) do
      {
        email: "newuser@example.com",
        password: "SecurePass123",
        password_confirmation: "SecurePass123",
        first_name: "John",
        last_name: "Doe"
      }
    end

    context "with valid parameters" do
      it "creates a new user" do
        expect do
          described_class.register(valid_params)
        end.to change(User, :count).by(1)
      end

      it "returns the created user" do
        user = described_class.register(valid_params)
        expect(user).to be_a(User)
        expect(user.email).to eq("newuser@example.com")
      end

      it "enqueues a welcome email job" do
        allow(WelcomeEmailJob).to receive(:perform_async)

        user = described_class.register(valid_params)

        expect(WelcomeEmailJob).to have_received(:perform_async).with(user.id)
      end
    end

    context "with weak password" do
      it "raises ValidationError for short password" do
        params = valid_params.merge(password: "Short1", password_confirmation: "Short1")

        expect do
          described_class.register(params)
        end.to raise_error(AuthenticationService::ValidationError, /at least 8 characters/)
      end

      it "raises ValidationError for missing uppercase" do
        params = valid_params.merge(password: "lowercase123", password_confirmation: "lowercase123")

        expect do
          described_class.register(params)
        end.to raise_error(AuthenticationService::ValidationError, /uppercase letter/)
      end

      it "raises ValidationError for missing lowercase" do
        params = valid_params.merge(password: "UPPERCASE123", password_confirmation: "UPPERCASE123")

        expect do
          described_class.register(params)
        end.to raise_error(AuthenticationService::ValidationError, /lowercase letter/)
      end

      it "raises ValidationError for missing digit" do
        params = valid_params.merge(password: "NoDigitsHere", password_confirmation: "NoDigitsHere")

        expect do
          described_class.register(params)
        end.to raise_error(AuthenticationService::ValidationError, /digit/)
      end
    end

    context "with invalid user data" do
      it "raises ValidationError for missing email" do
        params = valid_params.merge(email: "")

        expect do
          described_class.register(params)
        end.to raise_error(AuthenticationService::ValidationError)
      end

      it "raises ValidationError for duplicate email" do
        create(:user, email: "existing@example.com")
        params = valid_params.merge(email: "existing@example.com")

        expect do
          described_class.register(params)
        end.to raise_error(AuthenticationService::ValidationError)
      end
    end
  end
end
