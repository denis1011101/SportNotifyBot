# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

RSpec.describe SportNotifyBot::Parsers::TelegramChannelFetcher do
  let(:channel) { { name: "TestChannel", username: "@testchan" } }
  let(:channel_url) { "https://t.me/testchan" }
  let(:post_url) { "https://t.me/testchan/42" }

  let(:html_with_posts) do
    <<~HTML
      <html><body>
        <div class="tgme_widget_message_wrap">
          <div class="tgme_widget_message_text">Отличная игра Джоковича!</div>
          <a class="tgme_widget_message_date" href="#{post_url}">
            <time datetime="2024-06-01T12:00:00+00:00">01.06.2024</time>
          </a>
        </div>
        <div class="tgme_widget_message_wrap">
          <div class="tgme_widget_message_text">Федерер объявил о возвращении.</div>
          <a class="tgme_widget_message_date" href="https://t.me/testchan/43">
            <time datetime="2024-06-02T10:00:00+00:00">02.06.2024</time>
          </a>
        </div>
      </body></html>
    HTML
  end

  let(:html_empty_posts) do
    <<~HTML
      <html><body>
        <div class="tgme_widget_message_wrap">
          <div class="tgme_widget_message_text">   </div>
          <a class="tgme_widget_message_date" href="https://t.me/testchan/1">
            <time datetime="2024-06-01T12:00:00+00:00">01.06.2024</time>
          </a>
        </div>
        <div class="tgme_widget_message_wrap">
          <a class="tgme_widget_message_date" href="https://t.me/testchan/2">
            <time datetime="2024-06-01T13:00:00+00:00">01.06.2024</time>
          </a>
        </div>
      </body></html>
    HTML
  end

  before do
    stub_request(:get, "https://t.me/s/testchan")
      .to_return(status: 200, body: html_with_posts, headers: { "Content-Type" => "text/html" })
  end

  describe ".fetch_and_publish" do
    before do
      allow(SportNotifyBot::GistDataStore).to receive(:publish_with_filename)
      config = double(telegram_posts_gist_filename: "telegram_posts.json",
                      data_gist_token: "tok", data_gist_id: "abc123",
                      data_gist_raise_errors: false)
      allow(SportNotifyBot).to receive(:configuration).and_return(config)
    end

    it "fetches posts and publishes to gist" do
      described_class.fetch_and_publish([channel])
      expect(SportNotifyBot::GistDataStore).to have_received(:publish_with_filename)
        .with("telegram_posts.json", anything)
    end

    it "publishes valid JSON with fetched_at and posts keys" do
      captured = nil
      allow(SportNotifyBot::GistDataStore).to receive(:publish_with_filename) do |_f, content|
        captured = JSON.parse(content)
      end
      described_class.fetch_and_publish([channel])
      expect(captured).to include("fetched_at", "posts")
      expect(captured["posts"]).to be_an(Array)
      expect(captured["posts"].size).to eq(2)
    end

    it "sorts posts by published_at descending" do
      captured_posts = nil
      allow(SportNotifyBot::GistDataStore).to receive(:publish_with_filename) do |_f, content|
        captured_posts = JSON.parse(content)["posts"]
      end
      described_class.fetch_and_publish([channel])
      dates = captured_posts.map { |p| p["published_at"] }
      expect(dates).to eq(dates.sort.reverse)
    end
  end

  describe "post parsing" do
    it "skips posts with blank text" do
      stub_request(:get, "https://t.me/s/testchan")
        .to_return(status: 200, body: html_empty_posts)
      allow(SportNotifyBot::GistDataStore).to receive(:publish_with_filename)
      config = double(telegram_posts_gist_filename: "telegram_posts.json",
                      data_gist_token: "tok", data_gist_id: "abc123",
                      data_gist_raise_errors: false)
      allow(SportNotifyBot).to receive(:configuration).and_return(config)

      captured_posts = nil
      allow(SportNotifyBot::GistDataStore).to receive(:publish_with_filename) do |_f, content|
        captured_posts = JSON.parse(content)["posts"]
      end
      described_class.fetch_and_publish([channel])
      expect(captured_posts).to be_empty
    end

    it "truncates text longer than MAX_TEXT_LENGTH" do
      long_text = "А" * 600
      html = <<~HTML
        <html><body>
          <div class="tgme_widget_message_wrap">
            <div class="tgme_widget_message_text">#{long_text}</div>
            <a class="tgme_widget_message_date" href="#{post_url}">
              <time datetime="2024-06-01T12:00:00+00:00">01.06.2024</time>
            </a>
          </div>
        </body></html>
      HTML
      stub_request(:get, "https://t.me/s/testchan").to_return(status: 200, body: html)
      config = double(telegram_posts_gist_filename: "telegram_posts.json",
                      data_gist_token: "tok", data_gist_id: "abc123",
                      data_gist_raise_errors: false)
      allow(SportNotifyBot).to receive(:configuration).and_return(config)

      captured_posts = nil
      allow(SportNotifyBot::GistDataStore).to receive(:publish_with_filename) do |_f, content|
        captured_posts = JSON.parse(content)["posts"]
      end
      described_class.fetch_and_publish([channel])
      expect(captured_posts.first["text"].length).to be <= 501 # 500 chars + ellipsis
    end

    it "deduplicates posts with the same url" do
      dup_html = <<~HTML
        <html><body>
          <div class="tgme_widget_message_wrap">
            <div class="tgme_widget_message_text">Пост первый</div>
            <a class="tgme_widget_message_date" href="#{post_url}">
              <time datetime="2024-06-01T12:00:00+00:00">01.06.2024</time>
            </a>
          </div>
          <div class="tgme_widget_message_wrap">
            <div class="tgme_widget_message_text">Пост дубль</div>
            <a class="tgme_widget_message_date" href="#{post_url}">
              <time datetime="2024-06-01T12:00:00+00:00">01.06.2024</time>
            </a>
          </div>
        </body></html>
      HTML
      stub_request(:get, "https://t.me/s/testchan").to_return(status: 200, body: dup_html)
      config = double(telegram_posts_gist_filename: "telegram_posts.json",
                      data_gist_token: "tok", data_gist_id: "abc123",
                      data_gist_raise_errors: false)
      allow(SportNotifyBot).to receive(:configuration).and_return(config)

      captured_posts = nil
      allow(SportNotifyBot::GistDataStore).to receive(:publish_with_filename) do |_f, content|
        captured_posts = JSON.parse(content)["posts"]
      end
      described_class.fetch_and_publish([channel])
      expect(captured_posts.size).to eq(1)
    end
  end

  describe "error handling" do
    it "returns empty array when channel HTTP request fails" do
      stub_request(:get, "https://t.me/s/testchan").to_return(status: 503)
      config = double(telegram_posts_gist_filename: "telegram_posts.json",
                      data_gist_token: "tok", data_gist_id: "abc123",
                      data_gist_raise_errors: false)
      allow(SportNotifyBot).to receive(:configuration).and_return(config)
      allow(SportNotifyBot::GistDataStore).to receive(:publish_with_filename)

      captured_posts = nil
      allow(SportNotifyBot::GistDataStore).to receive(:publish_with_filename) do |_f, content|
        captured_posts = JSON.parse(content)["posts"]
      end
      expect { described_class.fetch_and_publish([channel]) }.not_to raise_error
      expect(captured_posts).to be_empty
    end

    it "returns empty array when network error occurs" do
      stub_request(:get, "https://t.me/s/testchan").to_raise(Net::OpenTimeout)
      config = double(telegram_posts_gist_filename: "telegram_posts.json",
                      data_gist_token: "tok", data_gist_id: "abc123",
                      data_gist_raise_errors: false)
      allow(SportNotifyBot).to receive(:configuration).and_return(config)
      allow(SportNotifyBot::GistDataStore).to receive(:publish_with_filename)

      expect { described_class.fetch_and_publish([channel]) }.not_to raise_error
    end
  end
end
