# frozen_string_literal: true

require "rails_helper"

RSpec.describe ErrorHandler do
  describe "module structure" do
    it "is defined as a module" do
      expect(described_class).to be_a(Module)
    end

    it "is included in ApplicationController" do
      expect(ApplicationController.included_modules).to include(described_class)
    end
  end
end
