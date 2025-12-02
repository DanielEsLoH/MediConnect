# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { should have_many(:medical_records).dependent(:destroy) }
    it { should have_many(:allergies).dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should have_secure_password }

    describe "email validation" do
      it "validates email format" do
        user = build(:user, email: "invalid_email")
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include("is invalid")
      end

      it "validates email uniqueness" do
        create(:user, email: "test@example.com")
        user = build(:user, email: "test@example.com")
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include("has already been taken")
      end

      it "is case insensitive" do
        create(:user, email: "Test@Example.com")
        user = build(:user, email: "test@example.com")
        expect(user).not_to be_valid
      end
    end

    describe "password validation" do
      it "requires minimum 8 characters" do
        user = build(:user, password: "Short1", password_confirmation: "Short1")
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include("is too short (minimum is 8 characters)")
      end
    end

    describe "phone number validation" do
      it "accepts valid phone formats" do
        valid_phones = ["+1234567890", "123-456-7890", "(123) 456-7890"]
        valid_phones.each do |phone|
          user = build(:user, phone_number: phone)
          expect(user).to be_valid
        end
      end

      it "rejects invalid phone formats" do
        user = build(:user, phone_number: "invalid_phone")
        expect(user).not_to be_valid
      end
    end
  end

  describe "callbacks" do
    it "normalizes email before save" do
      user = create(:user, email: "Test@Example.COM")
      expect(user.email).to eq("test@example.com")
    end
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active users" do
        active_user = create(:user, active: true)
        create(:user, :inactive)

        expect(User.active).to eq([active_user])
      end
    end

    describe ".by_email" do
      it "finds user by email" do
        user = create(:user, email: "test@example.com")
        expect(User.by_email("test@example.com")).to eq([user])
      end

      it "is case insensitive" do
        user = create(:user, email: "test@example.com")
        expect(User.by_email("TEST@EXAMPLE.COM")).to eq([user])
      end
    end

    describe ".search_by_name" do
      it "finds users by first name" do
        user = create(:user, first_name: "John", last_name: "Doe")
        expect(User.search_by_name("john")).to include(user)
      end

      it "finds users by last name" do
        user = create(:user, first_name: "John", last_name: "Doe")
        expect(User.search_by_name("doe")).to include(user)
      end
    end

    describe ".search_by_phone" do
      it "finds users by phone number" do
        user = create(:user, phone_number: "123-456-7890")
        expect(User.search_by_phone("123")).to include(user)
      end
    end
  end

  describe "instance methods" do
    describe "#full_name" do
      it "returns concatenated first and last name" do
        user = build(:user, first_name: "John", last_name: "Doe")
        expect(user.full_name).to eq("John Doe")
      end
    end

    describe "#age" do
      it "calculates age correctly" do
        user = build(:user, date_of_birth: 30.years.ago.to_date)
        expect(user.age).to be_within(1).of(30)
      end

      it "returns nil if date_of_birth is nil" do
        user = build(:user, date_of_birth: nil)
        expect(user.age).to be_nil
      end
    end

    describe "#as_json" do
      it "excludes password_digest" do
        user = create(:user)
        json = user.as_json
        expect(json).not_to have_key("password_digest")
      end
    end
  end

  describe "event publishing" do
    let(:event_publisher) { class_double(EventPublisher).as_stubbed_const }

    describe "on create" do
      it "publishes user.created event" do
        allow(event_publisher).to receive(:publish)

        user = create(:user)

        expect(event_publisher).to have_received(:publish).with(
          "user.created",
          hash_including(
            user_id: user.id,
            email: user.email,
            full_name: user.full_name
          )
        )
      end
    end

    describe "on update" do
      it "publishes user.updated event" do
        user = create(:user)
        allow(event_publisher).to receive(:publish)

        user.update(first_name: "Updated")

        expect(event_publisher).to have_received(:publish).with(
          "user.updated",
          hash_including(
            user_id: user.id,
            email: user.email
          )
        )
      end
    end

    describe "on destroy" do
      it "publishes user.deleted event" do
        user = create(:user)
        allow(event_publisher).to receive(:publish)

        user.destroy

        expect(event_publisher).to have_received(:publish).with(
          "user.deleted",
          hash_including(
            user_id: user.id,
            email: user.email
          )
        )
      end
    end
  end
end
