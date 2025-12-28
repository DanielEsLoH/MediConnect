# frozen_string_literal: true

require "rails_helper"

RSpec.describe Authenticatable do
  describe "module structure" do
    it "is defined as a module" do
      expect(described_class).to be_a(Module)
    end

    it "defines authenticate_request method" do
      expect(described_class.instance_methods).to include(:authenticate_request)
    end

    it "defines current_user_admin? method" do
      expect(described_class.instance_methods).to include(:current_user_admin?)
    end

    it "defines current_user_doctor? method" do
      expect(described_class.instance_methods).to include(:current_user_doctor?)
    end

    it "defines current_user_patient? method" do
      expect(described_class.instance_methods).to include(:current_user_patient?)
    end
  end

  describe "integration with ApplicationController" do
    it "is included in ApplicationController" do
      expect(ApplicationController.included_modules).to include(described_class)
    end
  end
end
