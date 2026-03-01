# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

RSpec.describe SportNotifyBot::GistDataStore do
  describe ".publish" do
    let(:config) do
      instance_double(
        SportNotifyBot::Configuration,
        data_gist_token: "ghp_token",
        data_gist_id: "a1b2c3d4",
        data_gist_filename: "sport.txt",
        data_gist_raise_errors: false
      )
    end

    before do
      allow(SportNotifyBot).to receive(:configuration).and_return(config)
    end

    it "updates gist with snapshot content" do
      stub_request(:patch, "https://api.github.com/gists/a1b2c3d4")
        .with(
          headers: {
            "Authorization" => "Bearer ghp_token",
            "Accept" => "application/vnd.github+json",
            "Content-Type" => "application/json",
            "X-GitHub-Api-Version" => "2022-11-28"
          },
          body: { files: { "sport.txt" => { content: "line 1\nline 2" } } }.to_json
        )
        .to_return(status: 200, body: "{}", headers: {})

      described_class.publish("line 1\nline 2")

      expect(a_request(:patch, "https://api.github.com/gists/a1b2c3d4")).to have_been_made.once
    end

    it "does nothing when gist credentials are missing" do
      allow(SportNotifyBot).to receive(:configuration).and_return(
        instance_double(
          SportNotifyBot::Configuration,
          data_gist_token: "",
          data_gist_id: "",
          data_gist_filename: "sport.txt",
          data_gist_raise_errors: false
        )
      )

      described_class.publish(["line 1"])

      expect(WebMock).not_to have_requested(:patch, /api\.github\.com/)
    end

    it "handles timeout without raising by default" do
      stub_request(:patch, "https://api.github.com/gists/a1b2c3d4").to_timeout

      expect { described_class.publish("line 1") }.not_to raise_error
      expect(a_request(:patch, "https://api.github.com/gists/a1b2c3d4")).to have_been_made.once
    end

    it "does not call github api when gist id is invalid" do
      allow(SportNotifyBot).to receive(:configuration).and_return(
        instance_double(
          SportNotifyBot::Configuration,
          data_gist_token: "ghp_token",
          data_gist_id: "not-hex",
          data_gist_filename: "sport.txt",
          data_gist_raise_errors: false
        )
      )

      described_class.publish("line 1")

      expect(WebMock).not_to have_requested(:patch, /api\.github\.com/)
    end
  end

  describe ".fetch" do
    let(:config) do
      instance_double(
        SportNotifyBot::Configuration,
        data_gist_token: "ghp_token",
        data_gist_id: "a1b2c3d4",
        data_gist_filename: "sport.txt",
        data_gist_raise_errors: false
      )
    end

    before do
      allow(SportNotifyBot).to receive(:configuration).and_return(config)
    end

    it "loads content from gist file" do
      stub_request(:get, "https://api.github.com/gists/a1b2c3d4")
        .to_return(
          status: 200,
          body: {
            files: {
              "sport.txt" => {
                content: "cached data"
              }
            }
          }.to_json
        )

      expect(described_class.fetch).to eq("cached data")
    end

    it "returns nil when configured filename is missing in gist" do
      stub_request(:get, "https://api.github.com/gists/a1b2c3d4")
        .to_return(
          status: 200,
          body: {
            files: {
              "other.txt" => {
                content: "wrong file"
              }
            }
          }.to_json
        )

      expect(described_class.fetch).to be_nil
    end
  end
end
