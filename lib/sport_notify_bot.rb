# frozen_string_literal: true

require_relative "sport_notify_bot/version"
require "faraday"
require "nokogiri"
require 'json'

ENV["TZ"] = "Asia/Yekaterinburg"
TOKEN = ENV["TOKEN"]
CHAT_ID = ENV["CHAT_ID"]

unless TOKEN && CHAT_ID
  puts "Ошибка: Переменные окружения TOKEN и CHAT_ID должны быть установлены."
  exit 1
end

module SportNotifyBot
  class Error < StandardError; end

  # Вспомогательный модуль для форматирования HTML
  module HtmlFormatter
    def self.escape(text)
      return "" unless text # Обработка nil на всякий случай
      text.to_s # Убедимся, что это строка
          .gsub('&', '&') # & должен заменяться первым!
          .gsub('<', '<')
          .gsub('>', '>')
    end

    def self.bold(text)
      # Делаем текст жирным, предполагая, что он УЖЕ экранирован
      "<b>#{text}</b>"
    end

    def self.italic(text)
      # Делаем текст курсивом, предполагая, что он УЖЕ экранирован
      "<i>#{text}</i>"
    end
  end

  class Parser
    MAX_MESSAGE_LENGTH = 4096
    URL = "https://www.sports.ru/"
    ACCORDION_GROUP_XPATH = '//div[@class="accordion-group teaser-group"]'

    def self.parse
      begin
        response = Faraday.get(URL)
        unless response.success?
          puts "Ошибка при получении страницы #{URL}: Статус #{response.status}"
          # Экранируем сообщение об ошибке для HTML
          return HtmlFormatter.escape("Не удалось загрузить данные со sports.ru (Статус: #{response.status}).")
        end
        doc = Nokogiri::HTML(response.body)
      rescue Faraday::Error => e
        puts "Ошибка сети при запросе к #{URL}: #{e.message}"
        # Экранируем сообщение об ошибке для HTML
        return HtmlFormatter.escape("Не удалось подключиться к sports.ru.")
      end

      result = []
      total_length = 0
      first_section = true

      doc.xpath(ACCORDION_GROUP_XPATH).each do |sport_section|
        sport_title_element = sport_section.at_xpath('.//span[@class="accordion__title"]/a')
        next unless sport_title_element

        sport_title = sport_title_element.text.strip
        # Экранируем части заголовка для HTML
        escaped_sport_name = HtmlFormatter.escape(sport_title.split('.').first.strip.capitalize)
        escaped_tournament_name = HtmlFormatter.escape(sport_title.split('.').drop(1).join('.').strip)

        # Добавляем пустую строку
        unless first_section
          next_part = "\n"
          if total_length + next_part.length > MAX_MESSAGE_LENGTH
            puts "Превышен лимит сообщения при добавлении разделителя секций"
            break
          end
          result << ""
          total_length += next_part.length
        else
          first_section = false
        end

        # Формируем ЖИРНЫЙ заголовок из экранированных частей с тегами <b>
        section_header = HtmlFormatter.bold("#{escaped_sport_name}, #{escaped_tournament_name}")

        if total_length + section_header.length + 1 > MAX_MESSAGE_LENGTH
           puts "Превышен лимит сообщения при добавлении заголовка: #{section_header}"
           break
        end
        result << section_header
        total_length += section_header.length + 1

        matches_in_section = 0

        sport_section.xpath('.//li[@class="teaser-event"]').each do |match_node|
          # --- Экранируем время/статус для HTML ---
          time_element = match_node.at_xpath('.//div[@class="teaser-event__status"]/span')
          time_raw = time_element ? time_element.text.strip : "??:??"
          escaped_time = HtmlFormatter.escape(time_raw)

          match_string = escaped_time # Начинаем строку

          # --- Логика для тенниса ---
          # Используем include? для проверки, так как имя спорта теперь просто текст
          if sport_title.downcase.include?('теннис')
            players_data = []
            player_nodes = match_node.xpath('.//div[contains(@class, "teaser-event__board-player")]')

            if player_nodes.length == 2
              player_nodes.each do |player_node|
                player_name_element = player_node.at_xpath('.//span[@class="teaser-event__board-player-name"]')
                player_name_raw = player_name_element ? player_name_element.text.strip : "Игрок ?"
                escaped_player_name = HtmlFormatter.escape(player_name_raw)

                flag_node = player_node.at_xpath('.//span[contains(@class, "icon-flag")]')
                country_name_raw = ""
                if flag_node && flag_node.has_attribute?('title')
                  country_name_raw = flag_node['title'].to_s.strip
                end

                player_display = escaped_player_name
                unless country_name_raw.empty?
                  escaped_country_name = HtmlFormatter.escape(country_name_raw)
                  # Скобки экранировать не нужно в HTML, если они не < > &
                  player_display += " (#{escaped_country_name})"
                end
                # Форматируем КУРСИВОМ с тегом <i>
                players_data << HtmlFormatter.italic(player_display)
              end

              # Экранируем счет для HTML
              score_div = match_node.at_xpath('.//div[@class="teaser-event__board-score"]')
              escaped_score_parts = [HtmlFormatter.escape("–"), HtmlFormatter.escape("–")]
              if score_div
                score_text_raw = score_div.text.strip
                parts_raw = score_text_raw.split(':').map(&:strip)
                if parts_raw.length == 2
                  escaped_score_parts = parts_raw.map { |p| HtmlFormatter.escape(p) }
                end
              end

              # Собираем строку матча, используя обычные разделители (HTML их не интерпретирует)
              match_string += " - #{players_data[0]} #{escaped_score_parts[0]} : #{escaped_score_parts[1]} #{players_data[1]}"
            else
              match_string += " - " + HtmlFormatter.escape("Не удалось распарсить игроков тенниса")
            end

          # --- Логика для остальных видов спорта ---
          else
            teams_data = []
            team_nodes = match_node.xpath('.//div[@class="teaser-event__board-player"]')

            if team_nodes.length == 2
              team_nodes.each do |team_node|
                team_name_element = team_node.at_xpath('.//a | .//span[@class="teaser-event__board-player-name"]')
                team_name_raw = team_name_element ? team_name_element.text.strip : "Команда ?"
                escaped_team_name = HtmlFormatter.escape(team_name_raw)

                flag_node = team_node.at_xpath('.//span[contains(@class, "icon-flag")]')
                country_name_raw = ""
                if flag_node && flag_node.has_attribute?('title')
                  title_attr = flag_node['title'].to_s.strip
                  country_name_raw = title_attr unless title_attr.empty?
                end

                team_display = escaped_team_name
                unless country_name_raw.empty?
                  escaped_country_name = HtmlFormatter.escape(country_name_raw)
                  team_display += " (#{escaped_country_name})"
                end
                # Форматируем КУРСИВОМ с тегом <i>
                teams_data << HtmlFormatter.italic(team_display)
              end

              # Экранируем счет для HTML
              score_element = match_node.at_xpath('.//a[contains(@class, "teaser-event__board-score")]')
              escaped_score_parts = [HtmlFormatter.escape("–"), HtmlFormatter.escape("–")]
              if score_element
                score_spans = score_element.xpath('./span')
                if score_spans.length >= 2
                  score1_raw = score_spans[0].text
                  score2_raw = score_spans[1].text
                  score1_cleaned = score1_raw.strip.gsub(/\s+/, ' ')
                  score2_cleaned = score2_raw.strip.gsub(/\s+/, ' ')
                  escaped_score_parts = [HtmlFormatter.escape(score1_cleaned), HtmlFormatter.escape(score2_cleaned)]
                end
              end

               # Собираем строку матча, используя обычные разделители
               match_string += " - #{teams_data[0]} #{escaped_score_parts[0]} : #{escaped_score_parts[1]} #{teams_data[1]}"
            else
               match_string += " - " + HtmlFormatter.escape("Не удалось распарсить команды")
            end
          end

          # Проверяем лимит перед добавлением матча
          if total_length + match_string.length + 1 > MAX_MESSAGE_LENGTH
             puts "Превышен лимит сообщения при добавлении матча: #{match_string}"
             break
          end

          result << match_string
          total_length += match_string.length + 1
          matches_in_section += 1
        end # end loop matches

        break if total_length >= MAX_MESSAGE_LENGTH
      end # end loop sport sections

      result.join("\n")
    end
  end

  class TelegramSender
    URL = "https://api.telegram.org/bot#{TOKEN}/sendMessage"

    def self.send
      message_text = Parser.parse
      if message_text.empty? || message_text.strip.empty?
        puts "Нет данных для отправки."
        return
      end

      # Формируем JSON с указанием parse_mode: HTML
      payload = {
        chat_id: CHAT_ID,
        text: message_text,
        parse_mode: 'HTML' # <<<--- ИЗМЕНЕНО НА HTML
      }.to_json

      # Отправляем сообщение
      begin
        response = Faraday.post(URL, payload, "Content-Type" => "application/json")

        unless response.success?
          puts "Ошибка при отправке сообщения в Telegram: Статус #{response.status}"
          puts "Тело ответа Telegram: #{response.body}"
          puts "--- Отправляемый текст (HTML) ---"
          puts message_text
          puts "--- Конец текста ---"
          return
        end

        puts "Сообщение успешно отправлено в чат #{CHAT_ID}."

      rescue Faraday::Error => e
         puts "Ошибка сети при отправке сообщения в Telegram: #{e.message}"
         if e.respond_to?(:response) && e.response
           puts "Статус: #{e.response[:status]}"
           puts "Тело ответа: #{e.response[:body]}"
         end
      end
    end
  end

  # Запускаем отправку
  TelegramSender.send
end
