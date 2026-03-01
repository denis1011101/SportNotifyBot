# frozen_string_literal: true

module SportNotifyBot
  # Класс для работы с командной строкой
  class CLI
    def self.start(args = ARGV) # rubocop:disable Metrics/MethodLength
      case args.first
      when "send", nil
        SportNotifyBot.run
      when "send_chat"
        SportNotifyBot.send_chat_only
      when "sync_gist"
        SportNotifyBot.sync_gist
      when "sync_tennis_gist"
        SportNotifyBot.sync_tennis_gist
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
          send              Собрать данные, обновить gist и отправить в Telegram
          send_chat         Отправить в Telegram данные из gist
          sync_gist         Собрать данные и обновить gist без Telegram
          sync_tennis_gist  Псевдоним sync_gist (обратная совместимость)
          version           Показать версию
          help              Показать эту справку
      HELP
    end
  end
end
