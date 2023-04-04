# frozen_string_literal: true

require "spec_helper"
require_relative "../lib/sport_notify_bot"

RSpec.describe SportNotifyBot::MyParser do
  describe ".parse" do
    context "when to check the messages" do
      it "returns an string with \n" do
        expect(SportNotifyBot::MyParser.parse).to be_an(String)
        expect(SportNotifyBot::MyParser.parse).to include("\n")
      end

      it "returns non-empty string" do
        expect(SportNotifyBot::MyParser.parse).not_to be_empty
      end

      it "returns strings in the expected format" do
        output = SportNotifyBot::MyParser.parse
        expect(output).to match(/.* - .* \(.+\) .* \(.+\) .* : .*/)
      end
    end

    context "when the message is too long" do
      it "returns a string of the expected length" do
        allow(SportNotifyBot::MyParser).to receive(:parse).and_return("a" * 4097)
        expect(SportNotifyBot::MyParser.parse.length).to eq(4096)
      end
    end
  end
end

# TODO: finish this test

# RSpec.describe SportNotifyBot::Sender do
#   describe ".send" do
#     it "returns a Faraday::Response object" do
#       expect(SportNotifyBot::Sender.send).to be_a(Faraday::Response)
#     end
#   end
# end
