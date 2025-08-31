# frozen_string_literal: true

module SportNotifyBot
  # Вспомогательный модуль для форматирования HTML
  module HtmlFormatter
    # Экранирование специальных символов HTML
    def self.escape(text)
      return "" unless text # Обработка nil на всякий случай

      text.to_s # Убедимся, что это строка
          .gsub("&", "&amp;") # & должен заменяться первым! В HTML это &amp;
          .gsub("<", "&lt;")
          .gsub(">", "&gt;")
    end

    # Делаем текст жирным, предполагая, что он УЖЕ экранирован
    def self.bold(text)
      "<b>#{text}</b>"
    end

    # Делаем текст курсивом, предполагая, что он УЖЕ экранирован
    def self.italic(text)
      "<i>#{text}</i>"
    end
  end
end
