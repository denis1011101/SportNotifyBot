# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"
require_relative "../lib/sport_notify_bot"

RSpec.describe SportNotifyBot::Parser do
  describe ".parse" do
    let(:dummy_response_body) { File.read("spec/fixtures/dummy_response_body.html") }
    before do
      stub_const("MAX_MESSAGE_LENGTH_IN_TEST", 4096)
      stub_request(:get, "https://www.sports.ru/").to_return(status: 200, body: dummy_response_body)
    end

    # TODO: finish this test
    context "when to check every array separately" do
      let(:dummy_countries) { File.read("spec/fixtures/dummy_countries.html") }
      let(:dummy_teams) { File.read("spec/fixtures/dummy_teams.html") }
      let(:dummy_scores) { File.read("spec/fixtures/dummy_scores.html") }
      let(:dummy_times) { File.read("spec/fixtures/dummy_times.html") }

      it "return correct arrays" do
        expect(SportNotifyBot::Parser.parse.countries).to eq(dummy_countries)
        expect(SportNotifyBot::Parser.parse.teams).to eq(dummy_teams)
        expect(SportNotifyBot::Parser.parse.scores).to eq(dummy_scores)
        expect(SportNotifyBot::Parser.parse.times).to eq(dummy_times)
      end
    end

    context "when to check the messages" do
      it "returns an string with \n" do
        expect(SportNotifyBot::Parser.parse).to be_an(String)
        expect(SportNotifyBot::Parser.parse).to include("\n")
      end

      it "returns non-empty string" do
        expect(SportNotifyBot::Parser.parse).not_to be_empty
      end

      it "returns strings in the expected format" do
        output = SportNotifyBot::Parser.parse
        expect(output).to match(/.* - .* \(.+\) .* \(.+\) .* : .*/)
      end
    end

    context "when the message is too long" do
      it "stops adding elements to the table array when the length of the joined strings exceeds the limit" do
        expect(SportNotifyBot::Parser.parse.length).to be >= SportNotifyBot::Parser::MAX_MESSAGE_LENGTH
        expect(SportNotifyBot::Parser.parse.length).to be <= MAX_MESSAGE_LENGTH_IN_TEST
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
