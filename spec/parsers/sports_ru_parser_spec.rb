# frozen_string_literal: true

require "spec_helper"
require "nokogiri"

RSpec.describe SportNotifyBot::Parsers::SportsRuParser do
  def team_nodes(*countries)
    players = countries.each_with_index.map do |country, idx|
      flag = country ? %(<span title="#{country}" class="icon-flag icon-flag_1285"></span>) : ""
      name = %(<a class="teaser-event__board-player-name">Команда #{idx + 1}</a>)
      %(<div class="teaser-event__board-player">#{name}#{flag}</div>)
    end
    Nokogiri::HTML.fragment(players.join).css("div.teaser-event__board-player")
  end

  describe ".parse_teams" do
    it "prefixes team name with emoji flag for known country" do
      expect(described_class.parse_teams(team_nodes("Россия"))).to eq(
        ["\u{1F1F7}\u{1F1FA} <i>Команда 1</i>"]
      )
    end

    it "keeps country in parentheses when flag is unknown" do
      expect(described_class.parse_teams(team_nodes("Атлантида"))).to eq(
        ["<i>Команда 1 (Атлантида)</i>"]
      )
    end

    it "renders plain name when there is no flag element" do
      expect(described_class.parse_teams(team_nodes(nil))).to eq(["<i>Команда 1</i>"])
    end
  end
end
