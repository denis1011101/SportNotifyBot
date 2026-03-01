# frozen_string_literal: true

require "spec_helper"

RSpec.describe SportNotifyBot do
  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(SportNotifyBot.configuration).to be_an_instance_of(SportNotifyBot::Configuration)
    end

    it "memoizes the configuration" do
      config1 = SportNotifyBot.configuration
      config2 = SportNotifyBot.configuration
      expect(config1).to be(config2)
    end
  end

  describe ".configure" do
    it "yields the configuration object" do
      expect { |b| SportNotifyBot.configure(&b) }.to yield_with_args(SportNotifyBot.configuration)
    end

    it "allows setting configuration values" do
      token = "new_test_token"
      SportNotifyBot.configure do |config|
        config.token = token
      end
      expect(SportNotifyBot.configuration.token).to eq(token)
    end
  end

  describe ".run" do
    it "calls TelegramSender.send_message" do
      expect(SportNotifyBot::TelegramSender).to receive(:send_message)
      SportNotifyBot.run
    end
  end

  describe ".send_chat_only" do
    it "calls TelegramSender.send_message_from_gist" do
      expect(SportNotifyBot::TelegramSender).to receive(:send_message_from_gist)
      SportNotifyBot.send_chat_only
    end
  end

  describe ".sync_gist" do
    it "calls MessageBuilder.build_message with gist publication enabled" do
      expect(SportNotifyBot::MessageBuilder).to receive(:build_message).with(publish_data_gist: true)
      SportNotifyBot.sync_gist
    end
  end

  # Тест для create_http_client, если такой метод есть
end
