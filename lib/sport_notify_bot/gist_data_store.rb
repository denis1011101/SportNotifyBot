# frozen_string_literal: true

require "faraday"
require "json"

module SportNotifyBot
  # Хранилище полного снапшота данных в GitHub Gist
  class GistDataStore
    GITHUB_GIST_ID_REGEX = /\A[0-9a-f]+\z/i
    REQUEST_TIMEOUT_SECONDS = 5

    class << self
      def publish_with_filename(filename, content)
        return if content.to_s.strip.empty?

        config = SportNotifyBot.configuration
        token = config.data_gist_token.to_s.strip
        gist_id = config.data_gist_id.to_s.strip
        filename = filename.to_s.strip

        if token.empty? || gist_id.empty?
          puts "Gist публикация отключена: DATA_GIST_TOKEN или DATA_GIST_ID не задан."
          return
        end

        return unless validate_config!(gist_id, filename, config)

        response = client.patch("/gists/#{gist_id}") do |req|
          req.headers["Authorization"] = "Bearer #{token}"
          req.headers["Accept"] = "application/vnd.github+json"
          req.headers["Content-Type"] = "application/json"
          req.headers["X-GitHub-Api-Version"] = "2022-11-28"
          req.body = { files: { filename => { content: content } } }.to_json
        end

        if response.success?
          puts "Данные обновлены в Gist #{gist_id} (#{filename})."
        else
          handle_error(config, StandardError.new("Ошибка обновления Gist: HTTP #{response.status}, body=#{response.body}"))
        end
      rescue Faraday::Error => e
        handle_error(config, e, prefix: "Сетевая ошибка при обновлении Gist")
      rescue StandardError => e
        handle_error(config, e, prefix: "Непредвиденная ошибка публикации в Gist")
      end

      def publish(content)
        return if content.to_s.strip.empty?

        config = SportNotifyBot.configuration
        token = config.data_gist_token.to_s.strip
        gist_id = config.data_gist_id.to_s.strip
        filename = config.data_gist_filename.to_s.strip

        if token.empty? || gist_id.empty?
          puts "Gist публикация отключена: DATA_GIST_TOKEN или DATA_GIST_ID не задан."
          return
        end

        return unless validate_config!(gist_id, filename, config)

        response = client.patch("/gists/#{gist_id}") do |req|
          req.headers["Authorization"] = "Bearer #{token}"
          req.headers["Accept"] = "application/vnd.github+json"
          req.headers["Content-Type"] = "application/json"
          req.headers["X-GitHub-Api-Version"] = "2022-11-28"
          req.body = { files: { filename => { content: content } } }.to_json
        end

        if response.success?
          puts "Снапшот данных обновлен в Gist #{gist_id} (#{filename})."
        else
          handle_error(config, StandardError.new("Ошибка обновления Gist: HTTP #{response.status}, body=#{response.body}"))
        end
      rescue Faraday::Error => e
        handle_error(config, e, prefix: "Сетевая ошибка при обновлении Gist")
      rescue StandardError => e
        handle_error(config, e, prefix: "Непредвиденная ошибка публикации в Gist")
      end

      def fetch
        config = SportNotifyBot.configuration
        gist_id = config.data_gist_id.to_s.strip
        filename = config.data_gist_filename.to_s.strip
        token = config.data_gist_token.to_s.strip

        if gist_id.empty?
          puts "Чтение из gist отключено: DATA_GIST_ID не задан."
          return nil
        end

        return nil unless validate_config!(gist_id, filename, config)

        response = client.get("/gists/#{gist_id}") do |req|
          req.headers["Accept"] = "application/vnd.github+json"
          req.headers["Authorization"] = "Bearer #{token}" unless token.empty?
          req.headers["X-GitHub-Api-Version"] = "2022-11-28"
        end

        unless response.success?
          handle_error(config, StandardError.new("Ошибка чтения Gist: HTTP #{response.status}, body=#{response.body}"))
          return nil
        end

        parsed = JSON.parse(response.body)
        files = parsed["files"] || {}
        entry = files[filename]
        unless entry
          handle_error(config, StandardError.new("Файл #{filename} не найден в Gist."))
          return nil
        end
        content = entry && entry["content"] ? entry["content"].to_s : nil

        if content.to_s.strip.empty?
          handle_error(config, StandardError.new("В Gist нет данных для файла #{filename}."))
          return nil
        end

        content
      rescue Faraday::Error => e
        handle_error(config, e, prefix: "Сетевая ошибка при чтении Gist")
        nil
      rescue JSON::ParserError => e
        handle_error(config, e, prefix: "Ошибка разбора ответа Gist")
        nil
      rescue StandardError => e
        handle_error(config, e, prefix: "Непредвиденная ошибка чтения Gist")
        nil
      end

      private

      def client
        Faraday.new("https://api.github.com") do |faraday|
          faraday.options.timeout = REQUEST_TIMEOUT_SECONDS
          faraday.options.open_timeout = REQUEST_TIMEOUT_SECONDS
        end
      end

      def validate_config!(gist_id, filename, config)
        unless gist_id.match?(GITHUB_GIST_ID_REGEX)
          handle_error(config, ArgumentError.new("Некорректный DATA_GIST_ID: ожидается hex-строка."))
          return false
        end

        if filename.empty?
          handle_error(config, ArgumentError.new("Пустой DATA_GIST_FILENAME в конфигурации."))
          return false
        end

        true
      end

      def handle_error(config, error, prefix: nil)
        message = if prefix
                    "#{prefix}: #{error.class} - #{error.message}"
                  else
                    "#{error.class} - #{error.message}"
                  end
        $stderr.puts(message)
        raise error if config&.respond_to?(:data_gist_raise_errors) && config.data_gist_raise_errors
      end
    end
  end
end
