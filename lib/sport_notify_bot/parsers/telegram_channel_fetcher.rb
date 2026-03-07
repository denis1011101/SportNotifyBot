# frozen_string_literal: true

require "net/http"
require "nokogiri"
require "json"
require "time"

module SportNotifyBot
  module Parsers
    # Fetches recent posts from public Telegram channels via t.me/s/username
    class TelegramChannelFetcher
      POSTS_PER_CHANNEL = 5
      MAX_TEXT_LENGTH = 500
      REQUEST_TIMEOUT = 10

      # channels: array of hashes with :name and :username keys
      def self.fetch_and_publish(channels)
        posts = channels.flat_map { |ch| fetch_channel(ch) }
        posts = deduplicate(posts)
        posts.sort_by! { |p| p[:published_at] }.reverse!

        payload = { fetched_at: Time.now.utc.iso8601, posts: posts }.to_json

        config = SportNotifyBot.configuration
        filename = config.telegram_posts_gist_filename
        SportNotifyBot::GistDataStore.publish_with_filename(filename, payload)
        puts "Опубликовано #{posts.size} постов из #{channels.size} каналов."
        posts
      end

      def self.fetch_channel(channel)
        username = channel[:username].to_s.delete_prefix("@")
        channel_name = channel[:name].to_s
        channel_url = "https://t.me/#{username}"
        url = "https://t.me/s/#{username}"

        puts "Fetching #{url}..."
        html = http_get(url)
        return [] if html.nil?

        doc = Nokogiri::HTML(html)
        parse_posts(doc, channel_name, channel_url, username)
      rescue StandardError => e
        puts "Ошибка при получении постов из #{channel[:username]}: #{e.class} - #{e.message}"
        []
      end

      def self.parse_posts(doc, channel_name, channel_url, username)
        posts = []

        doc.css(".tgme_widget_message_wrap").each do |wrap|
          text_node = wrap.at_css(".tgme_widget_message_text")
          next unless text_node

          text = text_node.text.strip
          next if text.empty?

          time_node = wrap.at_css(".tgme_widget_message_date time")
          published_at = begin
            Time.iso8601(time_node["datetime"].to_s).utc.iso8601 if time_node
          rescue ArgumentError
            nil
          end
          next if published_at.nil?

          msg_link = wrap.at_css(".tgme_widget_message_date")&.[]("href")
          post_url = msg_link || channel_url

          posts << {
            channel_name: channel_name,
            channel_url: channel_url,
            text: text.length > MAX_TEXT_LENGTH ? "#{text[0, MAX_TEXT_LENGTH]}…" : text,
            url: post_url,
            published_at: published_at
          }
        end

        posts.last(POSTS_PER_CHANNEL)
      end

      def self.deduplicate(posts)
        seen = {}
        posts.each_with_object([]) do |post, acc|
          next if seen[post[:url]]

          seen[post[:url]] = true
          acc << post
        end
      end

      def self.http_get(url)
        uri = URI.parse(url)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                            read_timeout: REQUEST_TIMEOUT,
                                            open_timeout: REQUEST_TIMEOUT) do |http|
          req = Net::HTTP::Get.new(uri)
          req["User-Agent"] = "Mozilla/5.0 (compatible; Ruby/#{RUBY_VERSION})"
          req["Accept-Language"] = "ru,en;q=0.9"
          res = http.request(req)
          res.is_a?(Net::HTTPSuccess) ? res.body.to_s : nil
        end
      end

      private_class_method :fetch_channel, :parse_posts, :deduplicate, :http_get
    end
  end
end
