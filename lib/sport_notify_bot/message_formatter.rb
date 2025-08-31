# frozen_string_literal: true

module SportNotifyBot
  # Класс для форматирования и обрезки сообщения перед отправкой
  class MessageFormatter
    # Обрезка сообщения, если оно больше максимальной длины Telegram
    def self.truncate_message(message, max_length: SportNotifyBot.configuration.max_message_length) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      # Проверяем, не превышает ли сообщение максимальную длину в байтах
      if message.bytesize > max_length
        puts "Финальное сообщение превышает лимит Telegram (#{message.bytesize} > #{max_length}). Обрезается."

        # Разбиваем сообщение на строки для более точной обрезки
        lines = message.split("\n")
        truncated_lines = []
        current_size = 0

        # Добавляем строки, пока не превысим лимит
        lines.each do |line|
          line_size = line.bytesize + 1 # +1 за перенос строки
          break unless current_size + line_size <= max_length

          truncated_lines << line
          current_size += line_size
        end

        # Собираем сообщение обратно
        truncated = truncated_lines.join("\n")

        # Проверяем, что обрезанная строка является валидным UTF-8
        until truncated.valid_encoding?
          truncated = truncated.byteslice(0, truncated.bytesize - 1)
        end

        # Балансируем HTML-теги
        truncated = balance_html_tags(truncated)

        message = truncated
        puts "Сообщение обрезано до #{message.bytesize} байт."
      end

      message
    end

    # Балансировка HTML тегов в обрезанном сообщении
    def self.balance_html_tags(text)
      open_bold_tags = text.scan(/<b>/).length
      closed_bold_tags = text.scan(%r{</b>}).length
      open_italic_tags = text.scan(/<i>/).length
      closed_italic_tags = text.scan(%r{</i>}).length

      (open_bold_tags - closed_bold_tags).times { text += "</b>" } if open_bold_tags > closed_bold_tags
      (open_italic_tags - closed_italic_tags).times { text += "</i>" } if open_italic_tags > closed_italic_tags

      puts "Баланс HTML: b #{open_bold_tags}/#{closed_bold_tags}, i #{open_italic_tags}/#{closed_italic_tags}"
      text
    end
  end
end
