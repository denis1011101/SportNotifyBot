# frozen_string_literal: true

require "ferrum"
require "nokogiri"

module SportNotifyBot
  module Parsers
    # Класс для извлечения данных с сайта Flashscore
    class FlashscoreFetcher
      class BrowserNotFound < StandardError; end
      class Timeout < StandardError; end
      class FetchError < StandardError; end

      FLASHSCORE_TENNIS_URL = "https://www.flashscore.com.ua/tennis/"
      FIRST_TOURNAMENT_HEADER_SELECTOR = 'div.sportName.tennis [data-testid="wcl-headerLeague"]'

      def self.fetch_tennis_doc
        browser_path = find_browser_path
        unless browser_path
          puts "Не удалось найти установленный Chrome или Chromium"
          raise BrowserNotFound, "Chrome/Chromium not found"
        end
        puts "Найден путь к браузеру: #{browser_path}"

        browser = Ferrum::Browser.new(
          headless: true,
          timeout: 30,
          process_timeout: 30,
          browser_options: {
            "disable-gpu" => nil,
            "no-sandbox" => nil,
            "disable-dev-shm-usage" => nil,
            "remote-debugging-port" => 9222
          },
          browser_path: browser_path
        )

        puts "Открываем страницу Flashscore: #{FLASHSCORE_TENNIS_URL}"
        browser.goto(FLASHSCORE_TENNIS_URL)

        puts "Ожидаем загрузки первого заголовка турнира..."
        browser.network.wait_for_idle

        timeout = 20
        start_time = Time.now
        selector = FIRST_TOURNAMENT_HEADER_SELECTOR
        puts "Ищем элемент по селектору: #{selector}"
        loop do
          break if Time.now - start_time >= timeout
          
          element_exists = browser.evaluate("!!document.querySelector('#{selector}')")
          if element_exists
            puts "Элемент найден!"
            break
          end
          puts "Элемент не найден, ждем 0.5 секунды..."
          sleep 0.5
        end

        unless browser.evaluate("!!document.querySelector('#{selector}')")
          raise Ferrum::TimeoutError, "Элемент не найден за #{timeout} секунд"
        end

        sleep 2
        puts "Страница загружена, получаем HTML..."
        html = browser.page.body
        Nokogiri::HTML(html)
      rescue Ferrum::TimeoutError => e
        puts "Ошибка таймаута при загрузке Flashscore: #{e.message}"
        raise Timeout, e.message
      rescue BrowserNotFound
        raise
      rescue StandardError => e
        puts "Ошибка при использовании Ferrum для Flashscore: #{e.class} - #{e.message}"
        puts e.backtrace.join("\n")
        raise FetchError, e.message
      ensure
        if defined?(browser) && browser
          puts "Закрываем браузер..."
          browser.quit
          puts "Браузер закрыт."
        end
      end

      def self.find_browser_path
        return ENV["BROWSER_PATH"] if ENV["BROWSER_PATH"] && File.exist?(ENV["BROWSER_PATH"])

        possible_paths = [
          "/usr/bin/google-chrome", "/usr/bin/chromium", "/usr/bin/chromium-browser",
          "/snap/bin/chromium", "/usr/bin/google-chrome-stable", "/usr/bin/chrome",
          "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
          "C:/Program Files/Google/Chrome/Application/chrome.exe",
          "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe"
        ]
        possible_paths.each { |path| return path if File.exist?(path) }

        begin
          %w[chromium google-chrome chrome chromium-browser].each do |name|
            path = `which #{name} 2>/dev/null`.strip
            return path if !path.empty? && File.exist?(path)
          end
        rescue Errno::ENOENT
        end

        nil
      end
    end
  end
end
