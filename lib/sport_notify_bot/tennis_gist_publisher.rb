# frozen_string_literal: true

require "faraday"
require "json"

module SportNotifyBot
  # Публикует только теннисную секцию в GitHub Gist
  class TennisGistPublisher
    GITHUB_GIST_ID_REGEX = /\A[0-9a-f]+\z/i
    REQUEST_TIMEOUT_SECONDS = 5

    class << self
      def publish(tennis_lines)
        return unless tennis_lines.is_a?(Array) && tennis_lines.any?

        config = SportNotifyBot.configuration
        token = config.tennis_gist_token.to_s.strip
        gist_id = config.tennis_gist_id.to_s.strip
        filename = config.tennis_gist_filename.to_s.strip

        if token.empty? || gist_id.empty?
          puts "Gist публикация отключена: TENNIS_GIST_TOKEN или TENNIS_GIST_ID не задан."
          return
        end

        unless gist_id.match?(GITHUB_GIST_ID_REGEX)
          handle_error(config, ArgumentError.new("Некорректный TENNIS_GIST_ID: ожидается hex-строка."))
          return
        end

        if filename.empty?
          handle_error(config, ArgumentError.new("Пустой TENNIS_GIST_FILENAME в конфигурации."))
          return
        end

        content = tennis_lines.join("\n")
        client = Faraday.new("https://api.github.com") do |faraday|
          faraday.options.timeout = REQUEST_TIMEOUT_SECONDS
          faraday.options.open_timeout = REQUEST_TIMEOUT_SECONDS
        end

        response = client.patch("/gists/#{gist_id}") do |req|
          req.headers["Authorization"] = "Bearer #{token}"
          req.headers["Accept"] = "application/vnd.github+json"
          req.headers["Content-Type"] = "application/json"
          req.headers["X-GitHub-Api-Version"] = "2022-11-28"
          req.body = { files: { filename => { content: content } } }.to_json
        end

        if response.success?
          puts "Теннисные события обновлены в Gist #{gist_id} (#{filename})."
        else
          handle_error(config, StandardError.new("Ошибка обновления Gist: HTTP #{response.status}, body=#{response.body}"))
        end
      rescue Faraday::Error => e
        handle_error(config, e, prefix: "Сетевая ошибка при обновлении Gist")
      rescue StandardError => e
        handle_error(config, e, prefix: "Непредвиденная ошибка публикации в Gist")
      end

      private

      def handle_error(config, error, prefix: nil)
        message = if prefix
                    "#{prefix}: #{error.class} - #{error.message}"
                  else
                    "#{error.class} - #{error.message}"
                  end
        $stderr.puts(message)
        raise error if config&.respond_to?(:tennis_gist_raise_errors) && config.tennis_gist_raise_errors
      end
    end
  end
end
