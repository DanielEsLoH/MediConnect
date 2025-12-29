# frozen_string_literal: true

require "rails_helper"

RSpec.describe Current do
  describe "attributes" do
    it "has request_id attribute" do
      expect(described_class).to respond_to(:request_id)
      expect(described_class).to respond_to(:request_id=)
    end

    it "can set and get request_id" do
      described_class.request_id = "test-request-123"
      expect(described_class.request_id).to eq("test-request-123")
    end

    it "inherits from ActiveSupport::CurrentAttributes" do
      expect(described_class.superclass).to eq(ActiveSupport::CurrentAttributes)
    end
  end

  after do
    described_class.reset
  end
end
