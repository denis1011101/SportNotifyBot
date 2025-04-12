# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

RSpec.describe SportNotifyBot::TelegramSender do
  let(:token) { "test_token" }
  let(:chat_id) { "123456789" }
  let(:message) { "Test message" }

  before do
    # Setup configuration double
    config = double(
      token: token,
      chat_id: chat_id,
      validate!: nil,
      max_message_length: 4096
    )
    allow(SportNotifyBot).to receive(:configuration).and_return(config)

    # Setup MessageBuilder double
    allow(SportNotifyBot::MessageBuilder).to receive(:build_message).and_return(message)

    # Setup MessageFormatter pass-through
    allow(SportNotifyBot::MessageFormatter).to receive(:truncate_message) { |msg| msg }

    # Stub Telegram API
    @telegram_request = stub_request(:post, "https://api.telegram.org/bot#{token}/sendMessage")
                       .with(
                         body: {
                           chat_id: chat_id,
                           text: message,
                           parse_mode: "HTML",
                           disable_web_page_preview: true
                         }.to_json,
                         headers: { "Content-Type" => "application/json" }
                       )
  end

  describe ".send_message" do
    context "when configuration is valid" do
      it "sends the message to Telegram API" do
        SportNotifyBot::TelegramSender.send_message
        expect(@telegram_request).to have_been_requested
      end
    end

    context "when the message is empty" do
      before do
        allow(SportNotifyBot::MessageBuilder).to receive(:build_message).and_return("")
      end

      it "does not send empty messages" do
        SportNotifyBot::TelegramSender.send_message
        expect(@telegram_request).not_to have_been_requested
      end
    end

    context "when Telegram API returns an error" do
      before do
        @telegram_request.to_return(
          status: 400,
          body: { ok: false, description: "Bad Request: can't parse entities" }.to_json
        )
      end

      it "handles the error gracefully" do
        expect { SportNotifyBot::TelegramSender.send_message }.not_to raise_error
      end
    end

    context "when there is a network error" do
      before do
        @telegram_request.to_raise(Faraday::ConnectionFailed.new("Connection failed"))
      end

      it "handles network errors gracefully" do
        expect { SportNotifyBot::TelegramSender.send_message }.not_to raise_error
      end
    end
  end
end
