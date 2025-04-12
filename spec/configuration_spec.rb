# frozen_string_literal: true

require "spec_helper"

RSpec.describe SportNotifyBot::Configuration do
  let(:config) { SportNotifyBot::Configuration.new }

  describe "#valid?" do
    context "when token and chat_id are present" do
      before do
        config.token = "test_token"
        config.chat_id = "123456789"
      end

      it "returns true" do
        expect(config.valid?).to be true
      end
    end

    context "when token is missing" do
      before do
        config.token = nil
        config.chat_id = "123456789"
      end

      it "returns false" do
        expect(config.valid?).to be false
      end
    end

    context "when chat_id is missing" do
      before do
        config.token = "test_token"
        config.chat_id = nil
      end

      it "returns false" do
        expect(config.valid?).to be false
      end
    end
  end

  describe "#validate!" do
    context "when configuration is valid" do
      before do
        config.token = "test_token"
        config.chat_id = "123456789"
      end

      it "does not raise an error" do
        expect { config.validate! }.not_to raise_error
      end
    end

    context "when configuration is invalid" do
      before do
        config.token = nil
        config.chat_id = nil
      end

      it "raises an error" do
        expect { config.validate! }.to raise_error(SportNotifyBot::Error)
      end
    end
  end
end
