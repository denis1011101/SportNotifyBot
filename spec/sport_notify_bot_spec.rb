# frozen_string_literal: true

require "spec_helper"
require_relative "../lib/sport_notify_bot"

RSpec.describe SportNotifyBot::MyParser do
  describe ".parse" do
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
end

# TODO: finish this test

# RSpec.describe SportNotifyBot::Sender do
#   describe ".send" do
#     it "returns a Faraday::Response object" do
#       expect(SportNotifyBot::Sender.send).to be_a(Faraday::Response)
#     end
#   end
# end
