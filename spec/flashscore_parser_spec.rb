# frozen_string_literal: true

require "spec_helper"
require "nokogiri"

RSpec.describe SportNotifyBot::Parsers::FlashscoreParser do # rubocop:disable Metrics/BlockLength
  before do
    allow(SportNotifyBot).to receive(:configuration).and_return(
      double(max_message_length: 4096)
    )
  end

  describe ".country_flag" do
    def match_node_with_flag(side, title)
      html = %(<div class="event__match">
        <span class="event__logo event__logo--#{side} flag" title="#{title}"></span>
      </div>)
      Nokogiri::HTML.fragment(html).at_css("div")
    end

    def match_node_without_flag
      html = %(<div class="event__match"></div>)
      Nokogiri::HTML.fragment(html).at_css("div")
    end

    it "returns emoji flag for known country" do
      node = match_node_with_flag("home", "France")
      expect(described_class.country_flag(node, "home")).to eq("\u{1F1EB}\u{1F1F7}")
    end

    it "returns USA flag" do
      node = match_node_with_flag("away", "USA")
      expect(described_class.country_flag(node, "away")).to eq("\u{1F1FA}\u{1F1F8}")
    end

    it "returns nil for World" do
      node = match_node_with_flag("home", "World")
      expect(described_class.country_flag(node, "home")).to be_nil
    end

    it "returns nil for unknown country" do
      node = match_node_with_flag("home", "Atlantis")
      expect(described_class.country_flag(node, "home")).to be_nil
    end

    it "returns nil when no flag element" do
      node = match_node_without_flag
      expect(described_class.country_flag(node, "home")).to be_nil
    end
  end

  describe ".build_match_line" do # rubocop:disable Metrics/BlockLength
    def build_match_html(home:, away:, time: "15:00", home_flag: nil, away_flag: nil, # rubocop:disable Metrics/ParameterLists
                         home_score: nil, away_score: nil, doubles: false)
      flag_home_html = home_flag ? %(<span class="event__logo event__logo--home flag" title="#{home_flag}"></span>) : ""
      flag_away_html = away_flag ? %(<span class="event__logo event__logo--away flag" title="#{away_flag}"></span>) : ""
      score_home_html = home_score ? %(<span class="event__score--home">#{home_score}</span>) : ""
      score_away_html = away_score ? %(<span class="event__score--away">#{away_score}</span>) : ""

      doubles_class = doubles ? " event__match--doubles" : ""
      if doubles
        home_parts = home.split(" / ")
        away_parts = away.split(" / ")
        participants = %(
          <div class="event__participant--home1">#{home_parts[0]}</div>
          <div class="event__participant--home2">#{home_parts[1]}</div>
          <div class="event__participant--away1">#{away_parts[0]}</div>
          <div class="event__participant--away2">#{away_parts[1]}</div>
        )
      else
        participants = %(
          <div class="event__participant--home">#{home}</div>
          <div class="event__participant--away">#{away}</div>
        )
      end

      html = %(<div class="event__match#{doubles_class}">
        <div class="event__time">#{time}</div>
        #{flag_home_html}#{flag_away_html}
        #{participants}
        #{score_home_html}#{score_away_html}
      </div>)
      Nokogiri::HTML.fragment(html).at_css("div.event__match")
    end

    it "builds line with flags" do
      node = build_match_html(home: "Halys Q.", away: "Walton A.", time: "01:00",
                              home_flag: "France", away_flag: "Australia")
      line = described_class.build_match_line(node)
      expect(line).to include("\u{1F1EB}\u{1F1F7}")
      expect(line).to include("\u{1F1E6}\u{1F1FA}")
      expect(line).to include("Halys Q.")
      expect(line).to include("Walton A.")
    end

    it "builds line without flags" do
      node = build_match_html(home: "Player A", away: "Player B", time: "12:00")
      line = described_class.build_match_line(node)
      expect(line).to eq("12:00 - <i>Player A</i> – : – <i>Player B</i>")
    end

    it "builds line with scores" do
      node = build_match_html(home: "Nadal R.", away: "Djokovic N.",
                              home_score: "2", away_score: "1",
                              home_flag: "Spain", away_flag: "Serbia")
      line = described_class.build_match_line(node)
      expect(line).to include("2 : 1")
      expect(line).to include("\u{1F1EA}\u{1F1F8}") # Spain
      expect(line).to include("\u{1F1F7}\u{1F1F8}") # Serbia
    end

    it "builds doubles line without flags" do
      node = build_match_html(home: "Mertens E. / Zhang S.", away: "Bucsa C. / Melichar N.",
                              doubles: true)
      line = described_class.build_match_line(node)
      expect(line).to include("Mertens E. / Zhang S.")
      expect(line).to include("Bucsa C. / Melichar N.")
    end
  end

  describe ".parse" do # rubocop:disable Metrics/BlockLength
    it "limits matches per tournament to MAX_MATCHES_PER_TOURNAMENT" do
      matches_html = 7.times.map do |i|
        %(<div class="event__match">
          <div class="event__time">#{format("%02d:00", i)}</div>
          <span class="event__logo event__logo--home flag" title="France"></span>
          <span class="event__logo event__logo--away flag" title="USA"></span>
          <div class="event__participant--home">Player H#{i}</div>
          <div class="event__participant--away">Player A#{i}</div>
        </div>)
      end.join

      html = %(<html><body>
        <div class="sportName tennis">
          <div data-testid="wcl-headerLeague">
            <div class="headerLeague__wrapper">
              <span data-testid="wcl-scores-overline-05">ATP - SINGLES:</span>
              <a class="headerLeague__title"><strong data-testid="wcl-scores-simple-text-01">Indian Wells (USA), hard</strong></a>
            </div>
          </div>
        </div>
        #{matches_html}
      </body></html>)

      doc = Nokogiri::HTML(html)
      allow(SportNotifyBot::Parsers::FlashscoreFetcher).to receive(:fetch_tennis_doc).and_return(doc)

      result, = described_class.parse
      match_lines = result.reject { |l| l.start_with?("<b>") || l.empty? }
      expect(match_lines.size).to eq(5)
    end

    it "returns error when browser not found" do
      allow(SportNotifyBot::Parsers::FlashscoreFetcher).to receive(:fetch_tennis_doc)
        .and_raise(SportNotifyBot::Parsers::FlashscoreFetcher::BrowserNotFound)

      result, = described_class.parse
      expect(result.first).to include("браузер не найден")
    end

    it "returns error on timeout" do
      allow(SportNotifyBot::Parsers::FlashscoreFetcher).to receive(:fetch_tennis_doc)
        .and_raise(SportNotifyBot::Parsers::FlashscoreFetcher::Timeout)

      result, = described_class.parse
      expect(result.first).to include("таймаут")
    end
  end
end
