# frozen_string_literal: true

require "base64"
require "faraday"
require "nokogiri"
require "json"

module SportNotifyBot
  # Класс для хранения конфигурационных параметров
  class Configuration
    DEFAULT_TENNIS_GIST_FILENAME = "tennis_events.txt"

    attr_accessor :token, :chat_id, :http_headers, :max_message_length,
                  :tennis_gist_token, :tennis_gist_id, :tennis_gist_filename,
                  :tennis_gist_raise_errors

    DEFAULT_UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " \
                 "AppleWebKit/537.36 (KHTML, like Gecko) " \
                 "Chrome/91.0.4472.124 Safari/537.36"

    def initialize
      @token = ENV["TOKEN"]
      @chat_id = ENV["CHAT_ID"]
      @tennis_gist_token = ENV["TENNIS_GIST_TOKEN"]
      @tennis_gist_id = ENV["TENNIS_GIST_ID"]
      raw_gist_filename = ENV["TENNIS_GIST_FILENAME"].to_s.strip
      @tennis_gist_filename = raw_gist_filename.empty? ? DEFAULT_TENNIS_GIST_FILENAME : raw_gist_filename
      @tennis_gist_raise_errors = ENV["TENNIS_GIST_RAISE_ERRORS"] == "1"
      @max_message_length = 4096 # Максимальная длина сообщения в Telegram
      @http_headers = {
        "User-Agent" => DEFAULT_UA,
        "Accept" => "text/html,application/xhtml+xml,application/xml",
        "Accept-Language" => "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7"
      }
    end

    # Проверка наличия обязательных параметров
    def valid?
      !token.nil? && token.to_s.strip != "" &&
        !chat_id.nil? && chat_id.to_s.strip != ""
    end

    # Проверяет обязательные параметры и выбрасывает исключение, если их нет
    def validate!
      raise Error, "Переменные окружения TOKEN и CHAT_ID должны быть установлены." unless valid?
    end
  end
end
