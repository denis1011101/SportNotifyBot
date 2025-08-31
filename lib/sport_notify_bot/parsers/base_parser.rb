# frozen_string_literal: true

module SportNotifyBot
  module Parsers
    # Базовый класс для всех парсеров
    class BaseParser
      # Метод, который должны переопределять наследники
      def self.parse
        raise NotImplementedError, "#{name}#parse не реализован"
      end

      # Общий метод для запроса страницы
      def self.fetch_page(url, error_message = "Не удалось загрузить данные") # rubocop:disable Metrics/MethodLength
        response = Faraday.get(url)
        unless response.success?
          error_msg = HtmlFormatter.escape("#{error_message} (Статус: #{response.status}).")
          puts error_msg
          return [false, error_msg]
        end
        [true, Nokogiri::HTML(response.body)]
      rescue Faraday::Error => e
        error_msg = HtmlFormatter.escape("#{error_message}: #{e.message}")
        puts error_msg
        [false, error_msg]
      end
    end
  end
end
