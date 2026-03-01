# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

RSpec.describe SportNotifyBot::TennisGistPublisher do
  describe ".publish" do
    let(:config) do
      instance_double(
        SportNotifyBot::Configuration,
        tennis_gist_token: "ghp_token",
        tennis_gist_id: "a1b2c3d4",
        tennis_gist_filename: "tennis.txt",
        tennis_gist_raise_errors: false
      )
    end

    before do
      allow(SportNotifyBot).to receive(:configuration).and_return(config)
    end

    it "updates gist with tennis content" do
      stub_request(:patch, "https://api.github.com/gists/a1b2c3d4")
        .with(
          headers: {
            "Authorization" => "Bearer ghp_token",
            "Accept" => "application/vnd.github+json",
            "Content-Type" => "application/json",
            "X-GitHub-Api-Version" => "2022-11-28"
          },
          body: { files: { "tennis.txt" => { content: "line 1\nline 2" } } }.to_json
        )
        .to_return(status: 200, body: "{}", headers: {})

      described_class.publish(["line 1", "line 2"])

      expect(a_request(:patch, "https://api.github.com/gists/a1b2c3d4")).to have_been_made.once
    end

    it "does nothing when gist credentials are missing" do
      allow(SportNotifyBot).to receive(:configuration).and_return(
        instance_double(
          SportNotifyBot::Configuration,
          tennis_gist_token: "",
          tennis_gist_id: "",
          tennis_gist_filename: "tennis.txt",
          tennis_gist_raise_errors: false
        )
      )

      described_class.publish(["line 1"])

      expect(WebMock).not_to have_requested(:patch, /api\.github\.com/)
    end

    it "handles timeout without raising by default" do
      stub_request(:patch, "https://api.github.com/gists/a1b2c3d4").to_timeout

      expect { described_class.publish(["line 1"]) }.not_to raise_error
      expect(a_request(:patch, "https://api.github.com/gists/a1b2c3d4")).to have_been_made.once
    end

    it "does not call github api when gist id is invalid" do
      allow(SportNotifyBot).to receive(:configuration).and_return(
        instance_double(
          SportNotifyBot::Configuration,
          tennis_gist_token: "ghp_token",
          tennis_gist_id: "not-hex",
          tennis_gist_filename: "tennis.txt",
          tennis_gist_raise_errors: false
        )
      )

      described_class.publish(["line 1"])

      expect(WebMock).not_to have_requested(:patch, /api\.github\.com/)
    end
  end
end
