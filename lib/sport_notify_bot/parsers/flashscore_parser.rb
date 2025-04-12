# frozen_string_literal: true

require "ferrum"

module SportNotifyBot
  module Parsers
    # Парсер для сайта Flashscore (теннис)
    class FlashscoreParser < BaseParser # Предполагаем, что BaseParser определен где-то еще
      FLASHSCORE_TENNIS_URL = "https://www.flashscore.com.ua/tennis/"
      # Селектор для первого заголовка турнира в секции тенниса
      FIRST_TOURNAMENT_HEADER_SELECTOR = 'div.sportName.tennis > div[data-testid="wcl-headerLeague"]'
      # Селектор для матчей (будем использовать для проверки типа узла)
      MATCH_SELECTOR_CLASS = 'event__match'

      def self.parse(max_length: SportNotifyBot.configuration.max_message_length) # Предполагаем, что configuration доступен
        result = []
        current_length = 0
        browser = nil # Инициализируем переменную вне блока try

        begin
          browser_path = find_browser_path
          unless browser_path
            error_msg = "Не удалось найти установленный Chrome или Chromium"
            puts error_msg
            # Предполагаем, что HtmlFormatter доступен
            heading = HtmlFormatter.bold(HtmlFormatter.escape("Теннис (браузер не найден)"))
            result << heading
            return [result, heading.length + 1]
          end
          puts "Найден путь к браузеру: #{browser_path}"

          browser = Ferrum::Browser.new(
            headless: true,
            timeout: 30, # Увеличим таймаут
            process_timeout: 30,
            browser_options: {
              "disable-gpu" => nil,
              "no-sandbox" => nil,
              "disable-dev-shm-usage" => nil, # Часто нужно в Docker/CI
              "remote-debugging-port" => 9222 # Может помочь с отладкой
            },
            browser_path: browser_path
          )
          puts "Открываем страницу Flashscore: #{FLASHSCORE_TENNIS_URL}"
          browser.goto(FLASHSCORE_TENNIS_URL)

          puts "Ожидаем загрузки первого заголовка турнира..."
          # Ждем появления первого заголовка турнира, вместо sleep
          browser.network.wait_for_idle

          # Используем Ruby-цикл вместо JavaScript-функции
          timeout = 20
          start_time = Time.now
          element_found = false

          puts "Ищем элемент по селектору: #{FIRST_TOURNAMENT_HEADER_SELECTOR}"
          while Time.now - start_time < timeout && !element_found
            # Проверяем наличие элемента с помощью evaluate
            element_exists = browser.evaluate("!!document.querySelector('#{FIRST_TOURNAMENT_HEADER_SELECTOR}')")
            if element_exists
              element_found = true
              puts "Элемент найден!"
              break
            else
              puts "Элемент не найден, ждем 0.5 секунды..."
              sleep 0.5
            end
          end

          raise Ferrum::TimeoutError, "Элемент не найден за #{timeout} секунд" unless element_found

          # Добавим небольшую паузу на всякий случай, если JS еще что-то дорисовывает
          sleep 2
          puts "Страница загружена, получаем HTML..."
          html = browser.page.body
          doc = Nokogiri::HTML(html)
          puts "HTML получен, начинаем парсинг..."

        rescue Ferrum::TimeoutError => e
          puts "Ошибка таймаута при загрузке Flashscore: #{e.message}"
          heading = HtmlFormatter.bold(HtmlFormatter.escape("Теннис (ошибка загрузки таймаут)"))
          result << heading
          return [result, heading.length + 1]
        rescue StandardError => e
          puts "Ошибка при использовании Ferrum для Flashscore: #{e.class} - #{e.message}"
          puts e.backtrace.join("\n") # Выводим стектрейс для диагностики
          heading = HtmlFormatter.bold(HtmlFormatter.escape("Теннис (ошибка доступа/обработки)"))
          result << heading
          return [result, heading.length + 1]
        ensure
          # Закрываем браузер, если он был создан
          if browser
            puts "Закрываем браузер..."
            browser.quit
            puts "Браузер закрыт."
          end
        end

        # Находим ПЕРВЫЙ заголовок турнира
        first_tournament_header = doc.at_css(FIRST_TOURNAMENT_HEADER_SELECTOR)

        unless first_tournament_header
          error_msg = HtmlFormatter.escape("Теннисные турниры на Flashscore не найдены (не найден заголовок).")
          puts error_msg
          result << HtmlFormatter.bold(error_msg)
          return [result, error_msg.length + 7 + 1] # 7 за <b></b>
        end

        # Извлекаем данные заголовка
        category_span = first_tournament_header.at_css('span[data-testid="wcl-scores-overline-05"]')
        tournament_link = first_tournament_header.at_css('a[data-testid="wcl-textLink"]') # Ищем ссылку с названием

        category_text = category_span ? category_span.text.strip : "Теннис"
        tournament_text = tournament_link ? tournament_link.text.strip : "Неизвестный турнир"

        # Извлекаем информацию о месте проведения турнира и поверхности корта
        if tournament_text.include?(",")
          parts = tournament_text.split(",")
          location = parts[1..-1].join(",").strip
          if location.include?("(") && location.include?(")")
            # Если уже есть информация о стране в скобках, оставляем как есть
            tournament_location = location
          else
            # Ищем информацию о стране в DOM
            country_element = first_tournament_header.at_css('.event__title--type')
            country = country_element ? country_element.text.strip : nil
            tournament_location = country ? "#{location} (#{country})" : location
          end

          # Добавляем информацию о поверхности корта, если есть
          surface_element = first_tournament_header.at_css('.event__title--info')
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
        # Ищем матчи, которые идут СРАЗУ ПОСЛЕ этого заголовка
        current_node = first_tournament_header.next_sibling
        while current_node && current_node.name == 'div' && current_node['class']&.include?(MATCH_SELECTOR_CLASS)
          match_node = current_node
          matches_found += 1

          # Извлекаем время/статус
          time_div = match_node.at_css('div.event__time')
          stage_div = match_node.at_css('div.event__stage--block') # Для статусов типа "Завершен"

          time_raw = if stage_div
                       stage_div.text.strip # Берем статус, если он есть
                     elsif time_div
                       time_div.text.strip # Иначе берем время
                     else
                       "??:??"
                     end
          escaped_time = HtmlFormatter.escape(time_raw)

          match_string = escaped_time

          # Игроки
          home_player_div = match_node.at_css('div.event__participant--home')
          away_player_div = match_node.at_css('div.event__participant--away')

          home_player_name_raw = home_player_div ? home_player_div.text.strip : "Игрок 1"
          away_player_name_raw = away_player_div ? away_player_div.text.strip : "Игрок 2"

          # Извлекаем информацию о флагах (странах) игроков
          home_flag = match_node.at_css('.event__logo--home')
          away_flag = match_node.at_css('.event__logo--away')

          # Получаем названия стран из атрибута title флагов
          home_country = home_flag && home_flag['title'] ? " (#{home_flag['title']})" : ""
          away_country = away_flag && away_flag['title'] ? " (#{away_flag['title']})" : ""

          # Добавляем страны к именам игроков
          home_player_with_country = "#{home_player_name_raw}#{home_country}"
          away_player_with_country = "#{away_player_name_raw}#{away_country}"

          escaped_home_player = HtmlFormatter.escape(home_player_with_country)
          escaped_away_player = HtmlFormatter.escape(away_player_with_country)

          italic_home_player = HtmlFormatter.italic(escaped_home_player)
          italic_away_player = HtmlFormatter.italic(escaped_away_player)

          # Счет
          score_home_span = match_node.at_css('.event__score--home')
          score_away_span = match_node.at_css('.event__score--away')

          score_home_raw = score_home_span ? score_home_span.text.strip : "–"
          score_away_raw = score_away_span ? score_away_span.text.strip : "–"

          escaped_score_home = HtmlFormatter.escape(score_home_raw)
          escaped_score_away = HtmlFormatter.escape(score_away_raw)

          match_string += " - #{italic_home_player} #{escaped_score_home} : #{escaped_score_away} #{italic_away_player}"

          # Проверяем лимит перед добавлением матча
          if current_length + match_string.length + 1 > max_length
             puts "Превышен лимит сообщения при добавлении матча Flashscore: #{match_string}"
             break
          end

          result << match_string
          current_length += match_string.length + 1

          current_node = current_node.next_sibling # Переходим к следующему элементу
        end # end while matches

        puts "Найдено матчей для первого турнира: #{matches_found}"

        if matches_found == 0
          no_matches_msg = HtmlFormatter.escape("Нет матчей для отображения в этом турнире.")
          result << no_matches_msg
          current_length += no_matches_msg.length + 1
        end

        [result, current_length]
      end

      private

      def self.find_browser_path
        # Ваш код поиска браузера (оставляем без изменений)
        return ENV["BROWSER_PATH"] if ENV["BROWSER_PATH"] && File.exist?(ENV["BROWSER_PATH"])
        possible_paths = [
          "/usr/bin/google-chrome", "/usr/bin/chromium", "/usr/bin/chromium-browser",
          "/snap/bin/chromium", "/usr/bin/google-chrome-stable", "/usr/bin/chrome",
          "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", # macOS
          "C:/Program Files/Google/Chrome/Application/chrome.exe", # Windows
          "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe" # Windows 32bit
        ]
        possible_paths.each { |path| return path if File.exist?(path) }
        begin
          ["chromium", "google-chrome", "chrome", "chromium-browser"].each do |browser_name|
            browser_path = `which #{browser_name} 2>/dev/null`.strip
            return browser_path if !browser_path.empty? && File.exist?(browser_path)
          end
        rescue Errno::ENOENT
          # 'which' command not found or other error
        end
        nil
      end
    end
  end
end
