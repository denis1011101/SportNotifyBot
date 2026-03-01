# frozen_string_literal: true

require "base64"
require "faraday"
require "nokogiri"
require "json"

module SportNotifyBot
  # Класс для хранения конфигурационных параметров
  class Configuration
    DEFAULT_DATA_GIST_FILENAME = "sport_events.txt"

    attr_accessor :token, :chat_id, :http_headers, :max_message_length,
                  :data_gist_token, :data_gist_id, :data_gist_filename,
                  :data_gist_raise_errors

    DEFAULT_UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " \
                 "AppleWebKit/537.36 (KHTML, like Gecko) " \
                 "Chrome/91.0.4472.124 Safari/537.36"

    def initialize
      @token = ENV["TOKEN"]
      @chat_id = ENV["CHAT_ID"]
      @data_gist_token = ENV["DATA_GIST_TOKEN"] || ENV["TENNIS_GIST_TOKEN"]
      @data_gist_id = ENV["DATA_GIST_ID"] || ENV["TENNIS_GIST_ID"]
      raw_gist_filename = (ENV["DATA_GIST_FILENAME"] || ENV["TENNIS_GIST_FILENAME"]).to_s.strip
      @data_gist_filename = raw_gist_filename.empty? ? DEFAULT_DATA_GIST_FILENAME : raw_gist_filename
      @data_gist_raise_errors = (ENV["DATA_GIST_RAISE_ERRORS"] || ENV["TENNIS_GIST_RAISE_ERRORS"]) == "1"
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
