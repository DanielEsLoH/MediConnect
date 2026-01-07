# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationsChannel, type: :channel do
  let(:user_id) { 123 }

  before do
    stub_connection current_user_id: user_id
  end

  describe "#subscribed" do
    it "successfully subscribes to the user's notifications stream" do
      subscribe
      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from("notifications_user_#{user_id}")
    end
  end

  describe "#unsubscribed" do
    it "successfully unsubscribes" do
      subscribe
      expect { unsubscribe }.not_to raise_error
    end
  end

  describe ".broadcast_to_user" do
    let(:notification) do
      {
        id: 1,
        title: "Test Notification",
        body: "This is a test",
        read: false
      }
    end

    it "broadcasts notification to user's stream" do
      expect {
        NotificationsChannel.broadcast_to_user(user_id, notification)
      }.to have_broadcasted_to("notifications_user_#{user_id}")
        .with(type: "notification", notification: notification)
    end
  end

  describe ".broadcast_to_users" do
    let(:user_ids) { [ 1, 2, 3 ] }
    let(:notification) do
      {
        id: 1,
        title: "Broadcast Notification",
        body: "Sent to multiple users"
      }
    end

    it "broadcasts notification to multiple users" do
      user_ids.each do |uid|
        expect(ActionCable.server).to receive(:broadcast).with(
          "notifications_user_#{uid}",
          { type: "notification", notification: notification }
        )
      end

      NotificationsChannel.broadcast_to_users(user_ids, notification)
    end
  end
end