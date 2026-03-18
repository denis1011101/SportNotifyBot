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

      MAX_MATCHES_PER_TOURNAMENT = 5

      def self.parse(max_length: SportNotifyBot.configuration.max_message_length) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        result = []
        current_length = 0

        begin
          doc = FlashscoreFetcher.fetch_tennis_doc
          puts "HTML получен, начинаем парсинг..."
        rescue FlashscoreFetcher::BrowserNotFound
          heading = HtmlFormatter.bold(HtmlFormatter.escape("Tennis (browser not found)"))
          result << heading
          return [result, heading.length + 1]
        rescue FlashscoreFetcher::Timeout
          heading = HtmlFormatter.bold(HtmlFormatter.escape("Tennis (loading timeout)"))
          result << heading
          return [result, heading.length + 1]
        rescue FlashscoreFetcher::FetchError, StandardError
          heading = HtmlFormatter.bold(HtmlFormatter.escape("Tennis (access/processing error)"))
          result << heading
          return [result, heading.length + 1]
        end

        headers = doc.css(FIRST_TOURNAMENT_HEADER_SELECTOR).to_a
        if headers.empty?
          error_msg = HtmlFormatter.escape("No tennis tournaments found on Flashscore (header not found).")
          puts error_msg
          result << HtmlFormatter.bold(error_msg)
          return [result, error_msg.length + 7 + 1]
        end

        puts "Найдено турниров тенниса: #{headers.length}"

        headers.each_with_index do |tournament_header, idx|
          category_span = tournament_header.at_css('span[data-testid="wcl-scores-overline-05"]')
          title_node = tournament_header.at_css(TOURNAMENT_TITLE_SELECTOR) ||
                       tournament_header.at_xpath(FIRST_TOURNAMENT_WRAPPER_XPATH)&.at_css(TOURNAMENT_TITLE_SELECTOR)

          category_text = category_span ? category_span.text.gsub(/[\s\u00a0]*:[\s\u00a0]*$/, "").strip : "Теннис"
          tournament_text = title_node ? title_node.text.strip : "Неизвестный турнир"

          if tournament_text.include?(",")
            parts = tournament_text.split(",")
            location = parts[1..].join(",").strip
            if location.include?("(") && location.include?(")")
              tournament_location = location
            else
              country_element = tournament_header.at_css(".event__title--type")
              country = country_element&.text&.strip
              tournament_location = country ? "#{location} (#{country})" : location
            end
            surface_element = tournament_header.at_css(".event__title--info")
            surface = surface_element ? surface_element.text.strip.downcase : nil
            tournament_text = "#{parts[0]}, #{tournament_location}#{surface ? ", #{surface}" : ""}"
          end

          escaped_category = HtmlFormatter.escape(category_text)
          escaped_tournament = HtmlFormatter.escape(tournament_text)
          header_string = HtmlFormatter.bold("#{escaped_category}, #{escaped_tournament}")

          header_len = header_string.length + 1
          if current_length + header_len > max_length
            puts "Превышен лимит перед добавлением заголовка турнира: #{tournament_text}"
            break
          end

          result << header_string
          current_length += header_len

          puts "Добавлен заголовок турнира #{idx + 1}: #{category_text}, #{tournament_text}"

          wrapper = tournament_header.at_xpath(FIRST_TOURNAMENT_WRAPPER_XPATH) || tournament_header.parent
          node = wrapper&.next_element
          matches_added = 0

          while node
            break if node["class"]&.include?("headerLeague__wrapper")
            break unless node.name == "div"

            nxt = node.next_element

            if node["class"]&.include?(MATCH_SELECTOR_CLASS)
              break if matches_added >= MAX_MATCHES_PER_TOURNAMENT

              match_string = build_match_line(node)
              line_len = match_string.length + 1
              if current_length + line_len > max_length
                puts "Превышен лимит сообщения при добавлении матча '#{match_string}' для турнира #{tournament_text}"
                return [result, current_length]
              end

              result << match_string
              current_length += line_len
              matches_added += 1
            end

            node = nxt
          end

          puts "Найдено матчей для турнира '#{tournament_text}': #{matches_added}"

          if idx < headers.length - 1
            if current_length + 1 > max_length
              puts "Превышен лимит перед добавлением пустой строки между турнирами"
              break
            end

            result << ""
            current_length += 1
          end
        end

        if result.size == 0 || (result.size == headers.size && result.all? { |r| r =~ /Теннис|Неизвестный турнир|Нет матчей/ })
          no_matches_msg = HtmlFormatter.escape("No matches to display.")
          result << no_matches_msg
          current_length += no_matches_msg.length + 1
        end

        [result, current_length]
      end

      def self.build_match_line(match_node)
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

          escaped_home = HtmlFormatter.escape(home_player_name_raw)
          escaped_away = HtmlFormatter.escape(away_player_name_raw)
        end

        home_flag = country_flag(match_node, "home")
        away_flag = country_flag(match_node, "away")

        italic_home = HtmlFormatter.italic(escaped_home)
        italic_away = HtmlFormatter.italic(escaped_away)

        score_home_span = match_node.at_css(".event__score--home")
        score_away_span = match_node.at_css(".event__score--away")
        score_home_raw = score_home_span ? score_home_span.text.strip : "–"
        score_away_raw = score_away_span ? score_away_span.text.strip : "–"
        escaped_score_home = HtmlFormatter.escape(score_home_raw)
        escaped_score_away = HtmlFormatter.escape(score_away_raw)

        home_display = home_flag ? "#{home_flag} #{italic_home}" : italic_home
        away_display = away_flag ? "#{away_flag} #{italic_away}" : italic_away

        "#{escaped_time} - #{home_display} #{escaped_score_home} : #{escaped_score_away} #{away_display}"
      end

      COUNTRY_TO_ISO = {
        "Algeria" => "DZ", "Andorra" => "AD", "Argentina" => "AR", "Armenia" => "AM",
        "Australia" => "AU", "Austria" => "AT", "Barbados" => "BB", "Belarus" => "BY",
        "Belgium" => "BE", "Bolivia" => "BO", "Bosnia and Herzegovina" => "BA",
        "Brazil" => "BR", "Bulgaria" => "BG", "Canada" => "CA", "Chile" => "CL",
        "China" => "CN", "Colombia" => "CO", "Costa Rica" => "CR", "Croatia" => "HR",
        "Cuba" => "CU", "Curaçao" => "CW", "Cyprus" => "CY", "Czech Republic" => "CZ",
        "Denmark" => "DK", "Dominican Republic" => "DO", "Ecuador" => "EC", "Egypt" => "EG",
        "El Salvador" => "SV", "Estonia" => "EE", "Finland" => "FI", "France" => "FR",
        "Georgia" => "GE", "Germany" => "DE", "Greece" => "GR", "Guatemala" => "GT",
        "Honduras" => "HN", "Hong Kong" => "HK", "Hungary" => "HU", "Iceland" => "IS",
        "India" => "IN", "Indonesia" => "ID", "Iran" => "IR", "Ireland" => "IE",
        "Israel" => "IL", "Italy" => "IT", "Jamaica" => "JM", "Japan" => "JP",
        "Kazakhstan" => "KZ", "Kenya" => "KE", "Latvia" => "LV", "Lithuania" => "LT",
        "Luxembourg" => "LU", "Malaysia" => "MY", "Mexico" => "MX", "Moldova" => "MD",
        "Monaco" => "MC", "Montenegro" => "ME", "Morocco" => "MA", "Netherlands" => "NL",
        "New Zealand" => "NZ", "Nigeria" => "NG", "North Macedonia" => "MK", "Norway" => "NO",
        "Northern Mariana Islands" => "MP", "Pakistan" => "PK", "Panama" => "PA",
        "Paraguay" => "PY", "Peru" => "PE", "Philippines" => "PH", "Poland" => "PL",
        "Portugal" => "PT", "Puerto Rico" => "PR", "Romania" => "RO", "Russia" => "RU",
        "Serbia" => "RS", "Singapore" => "SG", "Slovakia" => "SK", "Slovenia" => "SI",
        "South Africa" => "ZA", "South Korea" => "KR", "Spain" => "ES", "Sweden" => "SE",
        "Switzerland" => "CH", "Taiwan" => "TW", "Thailand" => "TH", "Tunisia" => "TN",
        "Turkey" => "TR", "USA" => "US", "Ukraine" => "UA", "United Kingdom" => "GB",
        "Uruguay" => "UY", "Uzbekistan" => "UZ", "Venezuela" => "VE", "Vietnam" => "VN"
      }.freeze

      def self.country_flag(match_node, side)
        flag_el = match_node.at_css("span.event__logo--#{side}[title]")
        return nil unless flag_el

        country = flag_el["title"].to_s.strip
        return nil if country.empty? || country == "World"

        iso = COUNTRY_TO_ISO[country]
        return nil unless iso

        iso.chars.map { |c| (0x1F1E6 + c.ord - "A".ord).chr("UTF-8") }.join
      end
    end
  end
end
