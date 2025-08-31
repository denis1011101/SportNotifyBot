# frozen_string_literal: true

require_relative "flashscore_fetcher"

module SportNotifyBot
  module Parsers
    # Парсер для сайта Flashscore (теннис)
    class FlashscoreParser < BaseParser
      FIRST_TOURNAMENT_HEADER_SELECTOR = 'div.sportName.tennis [data-testid="wcl-headerLeague"]'
      FIRST_TOURNAMENT_WRAPPER_XPATH = 'ancestor::div[contains(@class,"headerLeague__wrapper")]'
      TOURNAMENT_TITLE_SELECTOR = 'a.headerLeague__title strong[data-testid="wcl-scores-simple-text-01"], a.headerLeague__title'
      MATCH_SELECTOR_CLASS = "event__match"

      def self.parse(max_length: SportNotifyBot.configuration.max_message_length) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        result = []
        current_length = 0

        begin
          doc = FlashscoreFetcher.fetch_tennis_doc
          puts "HTML получен, начинаем парсинг..."
        rescue FlashscoreFetcher::BrowserNotFound
          heading = HtmlFormatter.bold(HtmlFormatter.escape("Теннис (браузер не найден)"))
          result << heading
          return [result, heading.length + 1]
        rescue FlashscoreFetcher::Timeout
          heading = HtmlFormatter.bold(HtmlFormatter.escape("Теннис (ошибка загрузки таймаут)"))
          result << heading
          return [result, heading.length + 1]
        rescue FlashscoreFetcher::FetchError, StandardError
          heading = HtmlFormatter.bold(HtmlFormatter.escape("Теннис (ошибка доступа/обработки)"))
          result << heading
          return [result, heading.length + 1]
        end

        # Находим ПЕРВЫЙ заголовок турнира
        first_tournament_header = doc.at_css(FIRST_TOURNAMENT_HEADER_SELECTOR)
        unless first_tournament_header
          error_msg = HtmlFormatter.escape("Теннисные турниры на Flashscore не найдены (не найден заголовок).")
          puts error_msg
          result << HtmlFormatter.bold(error_msg)
          return [result, error_msg.length + 7 + 1] # 7 за <b></b>
        end

        # Заголовок турнира
        category_span = first_tournament_header.at_css('span[data-testid="wcl-scores-overline-05"]')
        title_node = first_tournament_header.at_css(TOURNAMENT_TITLE_SELECTOR) ||
                     first_tournament_header.at_xpath(FIRST_TOURNAMENT_WRAPPER_XPATH)&.at_css(TOURNAMENT_TITLE_SELECTOR)

        category_text = category_span ? category_span.text.gsub(/\s*:\s*$/, "").strip : "Теннис"
        tournament_text = title_node ? title_node.text.strip : "Неизвестный турнир"

        # Место/поверхность
        if tournament_text.include?(",")
          parts = tournament_text.split(",")
          location = parts[1..].join(",").strip
          if location.include?("(") && location.include?(")")
            tournament_location = location
          else
            country_element = first_tournament_header.at_css(".event__title--type")
            country = country_element&.text&.strip
            tournament_location = country ? "#{location} (#{country})" : location
          end
          surface_element = first_tournament_header.at_css(".event__title--info")
          surface = surface_element ? surface_element.text.strip.downcase : nil
          tournament_text = "#{parts[0]}, #{tournament_location}#{surface ? ", #{surface}" : ""}"
        end

        escaped_category = HtmlFormatter.escape(category_text)
        escaped_tournament = HtmlFormatter.escape(tournament_text)
        header_string = HtmlFormatter.bold("#{escaped_category}, #{escaped_tournament}")

        result << header_string
        current_length += header_string.length + 1

        puts "Найден турнир: #{category_text}, #{tournament_text}"

        matches_found = 0
        header_wrapper = first_tournament_header.at_xpath(FIRST_TOURNAMENT_WRAPPER_XPATH) || first_tournament_header.parent
        current_node = header_wrapper&.next_element
        while current_node
          break if current_node["class"]&.include?("headerLeague__wrapper")
          break unless current_node.name == "div"

          next_node = current_node.next_element
          unless current_node["class"]&.include?(MATCH_SELECTOR_CLASS)
            current_node = next_node
            next
          end

          match_string = build_match_line(current_node)
          line_len = match_string.length + 1
          if current_length + line_len > max_length
            puts "Превышен лимит сообщения при добавлении матча Flashscore: #{match_string}"
            break
          end

          result << match_string
          current_length += line_len
          matches_found += 1
          current_node = next_node
        end

        puts "Найдено матчей для первого турнира: #{matches_found}"

        # Дозаполняем из 2-го и 3-го турниров при необходимости
        added_total = 0
        if matches_found < 5
          headers = doc.css(FIRST_TOURNAMENT_HEADER_SELECTOR).to_a

          # Второй турнир: до 3 матчей
          if headers[1]
            added = 0
            wrapper2 = headers[1].at_xpath(FIRST_TOURNAMENT_WRAPPER_XPATH) || headers[1].parent
            node = wrapper2&.next_element
            while node && added < 3
              break if node["class"]&.include?("headerLeague__wrapper")
              break unless node.name == "div"
              nxt = node.next_element

              if node["class"]&.include?(MATCH_SELECTOR_CLASS)
                match_string = build_match_line(node)
                line_len = match_string.length + 1
                break if current_length + line_len > max_length

                result << match_string
                current_length += line_len
                added += 1
                added_total += 1
              end
              node = nxt
            end
          end

          # Третий турнир: до 2 матчей
          if headers[2]
            added = 0
            wrapper3 = headers[2].at_xpath(FIRST_TOURNAMENT_WRAPPER_XPATH) || headers[2].parent
            node = wrapper3&.next_element
            while node && added < 2
              break if node["class"]&.include?("headerLeague__wrapper")
              break unless node.name == "div"
              nxt = node.next_element

              if node["class"]&.include?(MATCH_SELECTOR_CLASS)
                match_string = build_match_line(node)
                line_len = match_string.length + 1
                break if current_length + line_len > max_length

                result << match_string
                current_length += line_len
                added += 1
                added_total += 1
              end
              node = nxt
            end
          end
        end

        # Если совсем нет матчей
        if (matches_found + added_total).zero?
          no_matches_msg = HtmlFormatter.escape("Нет матчей для отображения в этом турнире.")
          result << no_matches_msg
          current_length += no_matches_msg.length + 1
        end

        [result, current_length]
      end

      # Строка матча (учитывает одиночные и парные)
      def self.build_match_line(match_node)
        # Время/статус
        time_div = match_node.at_css("div.event__time")
        stage_div = match_node.at_css("div.event__stage--block")
        time_raw = if stage_div
                     stage_div.text.strip
                   elsif time_div
                     time_div.text.strip
                   else
                     "??:??"
                   end
        escaped_time = HtmlFormatter.escape(time_raw)

        doubles = match_node["class"].to_s.include?("event__match--doubles")

        if doubles
          home_names = match_node.css("div.event__participant--home1, div.event__participant--home2")
                                 .map { |n| n.text.strip }.reject(&:empty?).join(" / ")
          away_names = match_node.css("div.event__participant--away1, div.event__participant--away2")
                                 .map { |n| n.text.strip }.reject(&:empty?).join(" / ")
          home_names = home_names.empty? ? "Пара 1" : home_names
          away_names = away_names.empty? ? "Пара 2" : away_names
          escaped_home = HtmlFormatter.escape(home_names)
          escaped_away = HtmlFormatter.escape(away_names)
        else
          home_player_div = match_node.at_css("div.event__participant--home")
          away_player_div = match_node.at_css("div.event__participant--away")
          home_player_name_raw = home_player_div ? home_player_div.text.strip : "Игрок 1"
          away_player_name_raw = away_player_div ? away_player_div.text.strip : "Игрок 2"

          home_flag = match_node.at_css(".event__logo--home")
          away_flag = match_node.at_css(".event__logo--away")
          home_country = home_flag && home_flag["title"] ? " (#{home_flag["title"]})" : ""
          away_country = away_flag && away_flag["title"] ? " (#{away_flag["title"]})" : ""

          escaped_home = HtmlFormatter.escape("#{home_player_name_raw}#{home_country}")
          escaped_away = HtmlFormatter.escape("#{away_player_name_raw}#{away_country}")
        end

        italic_home = HtmlFormatter.italic(escaped_home)
        italic_away = HtmlFormatter.italic(escaped_away)

        # Счёт
        score_home_span = match_node.at_css(".event__score--home")
        score_away_span = match_node.at_css(".event__score--away")
        score_home_raw = score_home_span ? score_home_span.text.strip : "–"
        score_away_raw = score_away_span ? score_away_span.text.strip : "–"
        escaped_score_home = HtmlFormatter.escape(score_home_raw)
        escaped_score_away = HtmlFormatter.escape(score_away_raw)

        "#{escaped_time} - #{italic_home} #{escaped_score_home} : #{escaped_score_away} #{italic_away}"
      end
    end
  end
end
