# frozen_string_literal: true

module SportNotifyBot
  module Parsers
    # Парсер для сайта Sports.ru
    class SportsRuParser < BaseParser
      SPORTS_RU_URL = "https://www.sports.ru/"
      ACCORDION_GROUP_XPATH = '//div[@class="accordion-group teaser-group"]'

      # Основной метод парсинга Sports.ru
      def self.parse(max_length: SportNotifyBot.configuration.max_message_length)
        result = []
        total_length = 0
        first_section = true

        # Получаем HTML-документ
        success, doc_or_error = fetch_page(SPORTS_RU_URL, "Не удалось загрузить данные со sports.ru")
        unless success
          result << doc_or_error
          total_length += doc_or_error.length + 1
          return [result, total_length]
        end

        # Парсинг разделов спорта
        doc_or_error.xpath(ACCORDION_GROUP_XPATH).each do |sport_section|
          # Получаем заголовок секции
          sport_title_element = sport_section.at_xpath('.//span[@class="accordion__title"]/a')
          next unless sport_title_element

          sport_title_ru = sport_title_element.text.strip

          # Пропускаем секцию тенниса, его парсим отдельно
          next if sport_title_ru.downcase.include?('теннис')

          # Обработка других видов спорта
          section_result, section_length = parse_sport_section(
            sport_section,
            sport_title_ru,
            first_section,
            max_length - total_length
          )

          # Добавляем результат секции если есть место
          if section_length <= max_length - total_length
            result.concat(section_result)
            total_length += section_length
            first_section = false
          else
            break
          end
        end

        [result, total_length]
      end

      private

      # Парсинг отдельной секции спорта
      def self.parse_sport_section(sport_section, sport_title_ru, first_section, available_length)
        result = []
        current_length = 0

        # Добавляем разделитель между секциями
        unless first_section
          result << ""
          current_length += 1
        end

        # Подготавливаем заголовок
        escaped_sport_name = HtmlFormatter.escape(sport_title_ru.split('.').first.strip.capitalize)
        escaped_tournament_name = HtmlFormatter.escape(sport_title_ru.split('.').drop(1).join('.').strip)
        section_header = HtmlFormatter.bold("#{escaped_sport_name}, #{escaped_tournament_name}")

        # Добавляем заголовок
        result << section_header
        current_length += section_header.length + 1

        # Парсим матчи
        matches_result, matches_length = parse_matches(sport_section, available_length - current_length)

        result.concat(matches_result)
        current_length += matches_length

        [result, current_length]
      end

      # Парсинг матчей в секции
      def self.parse_matches(sport_section, available_length)
        result = []
        current_length = 0

        sport_section.xpath('.//li[@class="teaser-event"]').each do |match_node|
          match_result, match_length = parse_match(match_node)

          # Проверяем, есть ли место для этого матча
          if match_length <= available_length - current_length
            result << match_result
            current_length += match_length
          else
            break
          end
        end

        [result, current_length]
      end

      # Парсинг данных одного матча
      def self.parse_match(match_node)
        # Экранируем время/статус
        time_element = match_node.at_xpath('.//div[@class="teaser-event__status"]/span')
        time_raw = time_element ? time_element.text.strip : "??:??"
        escaped_time = HtmlFormatter.escape(time_raw)

        match_string = escaped_time # Начинаем строку

        # Логика для обработки команд
        teams_data = []
        team_nodes = match_node.xpath('.//div[@class="teaser-event__board-player"]')

        if team_nodes.length == 2
          teams_data = parse_teams(team_nodes)

          # Экранируем счет
          score_parts = parse_score(match_node)

          match_string += " - #{teams_data[0]} #{score_parts[0]} : #{score_parts[1]} #{teams_data[1]}"
        else
          match_string += " - " + HtmlFormatter.escape("Не удалось распарсить команды")
        end

        [match_string, match_string.length + 1]  # +1 для '\n'
      end

      # Парсинг информации о командах
      def self.parse_teams(team_nodes)
        teams_data = []

        team_nodes.each do |team_node|
          team_name_element = team_node.at_xpath('.//a | .//span[@class="teaser-event__board-player-name"]')
          team_name_raw = team_name_element ? team_name_element.text.strip : "Команда ?"
          escaped_team_name = HtmlFormatter.escape(team_name_raw)

          # Обработка флага страны
          country_name = extract_country(team_node)

          team_display = escaped_team_name
          unless country_name.empty?
            escaped_country_name = HtmlFormatter.escape(country_name)
            team_display += " (#{escaped_country_name})"
          end

          teams_data << HtmlFormatter.italic(team_display)
        end

        teams_data
      end

      # Извлечение информации о стране команды
      def self.extract_country(team_node)
        flag_node = team_node.at_xpath('.//span[contains(@class, "icon-flag")]')
        return "" unless flag_node && flag_node.has_attribute?('title')

        title_attr = flag_node['title'].to_s.strip
        title_attr.empty? ? "" : title_attr
      end

      # Парсинг счета матча
      def self.parse_score(match_node)
        score_element = match_node.at_xpath('.//a[contains(@class, "teaser-event__board-score")]')
        default_scores = [HtmlFormatter.escape("–"), HtmlFormatter.escape("–")]

        return default_scores unless score_element

        score_spans = score_element.xpath('./span')
        return default_scores unless score_spans.length >= 2

        score1_raw = score_spans[0].text
        score2_raw = score_spans[1].text
        score1_cleaned = score1_raw.strip.gsub(/\s+/, ' ')
        score2_cleaned = score2_raw.strip.gsub(/\s+/, ' ')

        [HtmlFormatter.escape(score1_cleaned), HtmlFormatter.escape(score2_cleaned)]
      end
    end
  end
end
