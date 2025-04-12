# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

RSpec.describe SportNotifyBot::MessageBuilder do
  before do
    # Stub the configuration
    allow(SportNotifyBot).to receive(:configuration).and_return(
      double(max_message_length: 4096)
    )
  end

  describe ".build_message" do
    context "when both parsers return data" do
      before do
        # Mock FlashscoreParser to return some tennis data
        allow(SportNotifyBot::Parsers::FlashscoreParser).to receive(:parse).and_return([
          "<b>ATP - ОДИНОЧНЫЙ РАЗРЯД, Монте Карло (Монако), грунт</b>",
          "16:00 - <i>Давидович Фокина А.</i> - : - <i>Алькарас К.</i>",
          "17:30 - <i>Музетти Л.</i> - : - <i>Де Минаур А.</i>"
        ], 150)

        # Mock SportsRuParser to return some sports data
        allow(SportNotifyBot::Parsers::SportsRuParser).to receive(:parse).and_return([
          "<b>Футбол, Россия. Премьер-лига 2023/2024. 24 тур</b>",
          "12:00 - <i>Оренбург (Россия)</i> – : – <i>ЦСКА (Россия)</i>",
          "14:30 - <i>Пари НН (Россия)</i> – : – <i>Динамо (Россия)</i>"
        ], 200)
      end

      it "combines data from both parsers with tennis first" do
        result = SportNotifyBot::MessageBuilder.build_message

        # Tennis data should come first
        expect(result).to include("<b>ATP - ОДИНОЧНЫЙ РАЗРЯД")
        expect(result.index("<b>ATP")).to be < result.index("<b>Футбол")

        # Both data sets should be present
        expect(result).to include("Давидович Фокина А.")
        expect(result).to include("Оренбург (Россия)")

        # Should include a separator between sections
        sections = result.split("\n\n")
        expect(sections.length).to eq(2)
      end
    end

    context "when only tennis data is available" do
      before do
        allow(SportNotifyBot::Parsers::FlashscoreParser).to receive(:parse).and_return([
          "<b>ATP - ОДИНОЧНЫЙ РАЗРЯД, Монте Карло (Монако), грунт</b>",
          "16:00 - <i>Давидович Фокина А.</i> - : - <i>Алькарас К.</i>"
        ], 100)

        allow(SportNotifyBot::Parsers::SportsRuParser).to receive(:parse).and_return([], 0)
      end

      it "returns only tennis data" do
        result = SportNotifyBot::MessageBuilder.build_message

        expect(result).to include("ATP - ОДИНОЧНЫЙ РАЗРЯД")
        expect(result).to include("Давидович Фокина А.")
        expect(result).not_to include("\n\n") # No separator needed
      end
    end

    context "when only sports data is available" do
      before do
        allow(SportNotifyBot::Parsers::FlashscoreParser).to receive(:parse).and_return([], 0)

        allow(SportNotifyBot::Parsers::SportsRuParser).to receive(:parse).and_return([
          "<b>Футбол, Россия. Премьер-лига 2023/2024. 24 тур</b>",
          "12:00 - <i>Оренбург (Россия)</i> – : – <i>ЦСКА (Россия)</i>"
        ], 100)
      end

      it "returns only sports data" do
        result = SportNotifyBot::MessageBuilder.build_message

        expect(result).to include("Футбол, Россия")
        expect(result).to include("Оренбург (Россия)")
        expect(result).not_to include("ATP") # No tennis data
      end
    end

    context "when tennis data exceeds half the max length" do
      before do
        # Create a long tennis data array that exceeds half the length limit
        tennis_data = ["<b>ATP - ОДИНОЧНЫЙ РАЗРЯД, Монте Карло (Монако), грунт</b>"]
        20.times do |i|
          tennis_data << "#{i + 10}:00 - <i>Player #{i * 2}</i> - : - <i>Player #{i * 2 + 1}</i>"
        end

        allow(SportNotifyBot::Parsers::FlashscoreParser).to receive(:parse).and_return(
          tennis_data, 2100
        )

        allow(SportNotifyBot::Parsers::SportsRuParser).to receive(:parse).and_return([
          "<b>Футбол, Россия. Премьер-лига 2023/2024. 24 тур</b>",
          "12:00 - <i>Оренбург (Россия)</i> – : – <i>ЦСКА (Россия)</i>"
        ], 100)
      end

      it "limits tennis data to 10 matches" do
        result = SportNotifyBot::MessageBuilder.build_message

        lines = result.split("\n")
        tennis_section_end = lines.index("") || lines.length

        # Should have header + 10 matches (11 lines total) for tennis
        expect(tennis_section_end).to eq(11)

        # Should still include sports data
        expect(result).to include("Футбол, Россия")
      end
    end

    context "when parsers raise errors" do
      before do
        allow(SportNotifyBot::Parsers::FlashscoreParser).to receive(:parse)
          .and_raise(StandardError.new("Test tennis error"))

        allow(SportNotifyBot::Parsers::SportsRuParser).to receive(:parse)
          .and_raise(StandardError.new("Test sports error"))

        allow(SportNotifyBot::HtmlFormatter).to receive(:escape) { |text| text }
        allow(SportNotifyBot::HtmlFormatter).to receive(:bold) { |text| "<b>#{text}</b>" }
      end

      it "handles errors gracefully" do
        result = SportNotifyBot::MessageBuilder.build_message

        expect(result).to include("Теннис: Ошибка парсинга")
        expect(result).to include("Sports.ru: Ошибка парсинга")
      end
    end
  end
end
