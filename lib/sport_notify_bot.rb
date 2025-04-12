# frozen_string_literal: true

require 'dotenv/load'
require_relative "sport_notify_bot/version"
require_relative "sport_notify_bot/configuration"
require_relative "sport_notify_bot/html_formatter"
require_relative "sport_notify_bot/parsers/base_parser"
require_relative "sport_notify_bot/parsers/sports_ru_parser"
require_relative "sport_notify_bot/parsers/flashscore_parser"
require_relative "sport_notify_bot/telegram_sender"
require_relative "sport_notify_bot/message_formatter"
require_relative "sport_notify_bot/message_builder"
require_relative "sport_notify_bot/cli"

# Основной модуль приложения
module SportNotifyBot
  class Error < StandardError; end

  # Установка часового пояса по умолчанию
  ENV["TZ"] = "Asia/Yekaterinburg"

  class << self
    attr_writer :configuration

    # Метод доступа к конфигурации
    def configuration
      @configuration ||= Configuration.new
    end

    # Метод для настройки через блок
    def configure
      yield(configuration) if block_given?
    end

    # Запуск основного функционала
    def run
      TelegramSender.send_message
    end

    # Создание клиента HTTP
    def create_http_client
      Faraday.new do |builder|
        configuration.http_headers.each do |key, value|
          builder.headers[key] = value
        end
        # Добавляем cookie_jar если он доступен
        builder.use :cookie_jar if defined?(FaradayCookieJar)
      end
    end
  end
end
