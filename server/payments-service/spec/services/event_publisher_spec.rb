# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventPublisher do
  describe "class methods" do
    it "responds to .publish" do
      expect(described_class).to respond_to(:publish)
    end
  end
end
