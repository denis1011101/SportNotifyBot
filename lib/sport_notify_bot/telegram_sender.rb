# frozen_string_literal: true

require "faraday"
require "json"

module SportNotifyBot
  # Класс для отправки сообщений в Telegram
  class TelegramSender
    # Метод для отправки собранного сообщения в Telegram
    def self.send_message
      SportNotifyBot.configuration.validate!

      message_text = MessageBuilder.build_message
      if message_text.nil? || message_text.strip.empty?
        puts "Сообщение для отправки пустое, отправка отменена."
        return
      end

      message_text = MessageFormatter.truncate_message(message_text)
      send_to_telegram(message_text)
    end

    # Отправка сообщения в Telegram API
    def self.send_to_telegram(message_text) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      token = SportNotifyBot.configuration.token
      chat_id = SportNotifyBot.configuration.chat_id
      url = "https://api.telegram.org/bot#{token}/sendMessage"

      payload = {
        chat_id: chat_id,
        text: message_text,
        parse_mode: "HTML",
        disable_web_page_preview: true
      }.to_json

      puts "Отправка сообщения в чат #{chat_id}..."
      begin
        response = Faraday.post(url, payload, "Content-Type" => "application/json")

        response_body = begin
          JSON.parse(response.body)
        rescue StandardError
          { "description" => "Не удалось разобрать ответ Telegram" }
        end

        unless response.success?
          puts "Ошибка при отправке сообщения в Telegram: Статус #{response.status}"
          puts "Ответ Telegram: #{response_body["description"] || response.body}"
          puts "--- Отправляемый текст (HTML) ---"
          puts message_text # Выводим то, что пытались отправить
          puts "--- Конец текста ---"
          return
        end

        puts "Сообщение успешно отправлено в чат #{chat_id}."
      rescue Faraday::ConnectionFailed => e
        puts "Ошибка соединения с Telegram API: #{e.message}"
      rescue Faraday::TimeoutError => e
        puts "Таймаут при запросе к Telegram API: #{e.message}"
      rescue Faraday::Error => e # Общая ошибка Faraday
        puts "Ошибка сети при отправке сообщения в Telegram: #{e.class} - #{e.message}"
        if e.respond_to?(:response) && e.response
          puts "Статус: #{e.response[:status]}"
          puts "Тело ответа: #{e.response[:body]}"
        end
      rescue JSON::ParserError => e
        puts "Ошибка разбора JSON ответа от Telegram: #{e.message}"
        puts "Тело ответа: #{response.body}" # Показать тело ответа, которое не удалось разобрать
      rescue StandardError => e # Другие возможные ошибки
        puts "Непредвиденная ошибка при отправке сообщения: #{e.class} - #{e.message}"
        puts e.backtrace.join("\n")
      end
    end
  end
end
