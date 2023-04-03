# frozen_string_literal: true

require_relative "sport_notify_bot/version"
require "faraday"
require "nokogiri"

ENV['TZ'] = 'Asia/Yekaterinburg'
TOKEN = ENV['TOKEN']
CHAT_ID = ENV['CHAT_ID']

module SportNotifyBot
  class Error < StandardError; end

  class MyParser
    def self.parse
      url = "https://www.sports.ru/"
      response = Faraday.get(url)
      doc = Nokogiri::HTML(response.body)

      countries = doc.xpath('//div[@class="teaser-event__board-player"]/span')
                     .map { |team| team["title"] }.compact
      teams = doc.xpath('//div[@class="teaser-event__board-player"]')
                 .map { |team| team.text.strip }.compact
      score = doc.xpath('//a[@class="teaser-event__board-score piwikTrackContent piwikContentIgnoreInteraction"]/span')
                 .map { |score| score.text.strip }.compact
      times = doc.xpath("//div[@class = 'teaser-event__status']")
                 .map { |score| score.text.strip.gsub(/\s+/, " ") }.compact

      table = []
      teams.each_slice(2).with_index do |(team1, team2), index|
        table << "#{times[index]} - #{team1} (#{countries[index * 2]}) "\
                 "#{team2} (#{countries[index * 2 + 1]}) "\
                 "#{score[index * 2]} : #{score[index * 2 + 1]}"
      end

      table.join("\n")
    end
  end

  class Sender
    def self.send
      url = "https://api.telegram.org/bot#{TOKEN}/sendMessage"
      Faraday.post(url, { chat_id: CHAT_ID, text: MyParser.parse })
    end
  end

  Sender.send
end
