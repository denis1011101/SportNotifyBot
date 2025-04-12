# frozen_string_literal: true

module SportNotifyBot
  # Класс для работы с командной строкой
  class CLI
    def self.start(args = ARGV)
      case args.first
      when "send", nil
        SportNotifyBot.run
      when "version"
        puts "SportNotifyBot версия #{SportNotifyBot::VERSION}"
      when "help"
        show_help
      else
        puts "Неизвестная команда: #{args.first}"
        show_help
      end
    end

    def self.show_help
      puts <<~HELP
        Использование: sport_notify_bot [КОМАНДА]

        Доступные команды:
          send      Собрать и отправить спортивное уведомление (по умолчанию)
          version   Показать версию
          help      Показать эту справку
      HELP
    end
  end
end
