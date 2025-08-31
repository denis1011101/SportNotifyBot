# frozen_string_literal: true
# rubocop:disable Metrics/BlockLength

require "spec_helper"
require "webmock/rspec"

RSpec.describe SportNotifyBot::MessageBuilder do
  before do
    # Стабы и моки перенесем в отдельные примеры, чтобы избежать конфликтов
    allow(SportNotifyBot).to receive(:configuration).and_return(
      double(max_message_length: 4096)
    )

    # Мокируем HtmlFormatter для всех тестов
    allow(SportNotifyBot::HtmlFormatter).to receive(:escape) { |text| text }
    allow(SportNotifyBot::HtmlFormatter).to receive(:bold) { |text| "<b>#{text}</b>" }
    allow(SportNotifyBot::HtmlFormatter).to receive(:italic) { |text| "<i>#{text}</i>" }
  end

  describe ".build_message" do
    context "when both parsers return data" do
      it "combines data from both parsers with tennis first" do
        # Используем переменные для хранения данных
        tennis_data = [
          "<b>ATP - ОДИНОЧНЫЙ РАЗРЯД, Монте Карло (Монако), грунт</b>",
          "16:00 - <i>Давидович Фокина А.</i> - : - <i>Алькарас К.</i>",
          "17:30 - <i>Музетти Л.</i> - : - <i>Де Минаур А.</i>"
        ]

        sports_data = [
          "<b>Футбол, Россия. Премьер-лига 2023/2024. 24 тур</b>",
          "12:00 - <i>Оренбург (Россия)</i> – : – <i>ЦСКА (Россия)</i>",
          "14:30 - <i>Пари НН (Россия)</i> – : – <i>Динамо (Россия)</i>"
        ]

        # Настраиваем моки, используя allow вместо expect
        allow(SportNotifyBot::Parsers::FlashscoreParser).to receive(:parse)
          .with(max_length: 4096)
          .and_return([tennis_data, 150])

        allow(SportNotifyBot::Parsers::SportsRuParser).to receive(:parse)
          .with(max_length: instance_of(Integer))
          .and_return([sports_data, 200])

        # Вызываем тестируемый метод
        result = SportNotifyBot::MessageBuilder.build_message
        # Выводим результат для отладки
        puts "Результат: #{result}"

        # Tennis data should come first
        expect(result).to include("<b>ATP - ОДИНОЧНЫЙ РАЗРЯД")
        expect(result.index("<b>ATP")).to be < result.index("<b>Футбол")

        # Both data sets should be present
        expect(result).to include("Давидович Фокина А.")
        expect(result).to include("Оренбург (Россия)")

        # Should include a separator between sections
        sections = result.split("\n\n")
        expect(sections.length).to eq(2)

        # Проверяем количество вызовов
        expect(SportNotifyBot::Parsers::FlashscoreParser).to have_received(:parse).once
        expect(SportNotifyBot::Parsers::SportsRuParser).to have_received(:parse).once
      end
    end

    context "when only tennis data is available" do
      before do
        # Проблема в возвращаемом значении: моки должны возвращать массив и длину
        # как отдельные значения, а не как массив [массив_данных, длина]
        tennis_data = [
          "<b>ATP - ОДИНОЧНЫЙ РАЗРЯД, Монте Карло (Монако), грунт</b>",
          "16:00 - <i>Давидович Фокина А.</i> - : - <i>Алькарас К.</i>"
        ]

        # Исправляем возвращаемое значение, чтобы оно соответствовало ожиданиям MessageBuilder
        allow(SportNotifyBot::Parsers::FlashscoreParser).to receive(:parse)
          .with(max_length: 4096)
          .and_return([tennis_data, 100])

        # Явно указываем max_length, чтобы соответствовать сигнатуре метода
        allow(SportNotifyBot::Parsers::SportsRuParser).to receive(:parse)
          .with(max_length: instance_of(Integer))
          .and_return([[], 0])
      end

      it "returns only tennis data" do
        result = SportNotifyBot::MessageBuilder.build_message

        # Добавим отладочный вывод
        puts "Результат только тенниса: #{result}"

        expect(result).to include("ATP - ОДИНОЧНЫЙ РАЗРЯД")
        expect(result).to include("Давидович Фокина А.")
        expect(result).not_to include("\n\n") # No separator needed
      end
    end

    context "when only sports data is available" do
      before do
        # Проблема может быть в формате возвращаемых данных: давайте уточним
        allow(SportNotifyBot::Parsers::FlashscoreParser).to receive(:parse)
          .with(max_length: 4096)
          .and_return([[], 0]) # Возвращаем пустой массив и длину 0

        sports_data = [
          "<b>Футбол, Россия. Премьер-лига 2023/2024. 24 тур</b>",
          "12:00 - <i>Оренбург (Россия)</i> – : – <i>ЦСКА (Россия)</i>"
        ]

        allow(SportNotifyBot::Parsers::SportsRuParser).to receive(:parse)
          .with(max_length: instance_of(Integer))
          .and_return([sports_data, 100])
      end

      it "returns only sports data" do
        # Добавим отладочный вывод, чтобы понять, что происходит
        begin
          flash_data, flash_length = SportNotifyBot::Parsers::FlashscoreParser.parse(max_length: 4096)
          puts "FlashscoreParser мок вернул: #{flash_data.inspect}, #{flash_length}"
        rescue StandardError => e
          puts "Ошибка при вызове FlashscoreParser: #{e.message}"
        end

        begin
          sports_data, sports_length = SportNotifyBot::Parsers::SportsRuParser.parse(max_length: 4096)
          puts "SportsRuParser мок вернул: #{sports_data.inspect}, #{sports_length}"
        rescue StandardError => e
          puts "Ошибка при вызове SportsRuParser: #{e.message}"
        end

        result = SportNotifyBot::MessageBuilder.build_message
        puts "Результат в тесте only sports data: #{result}"

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

        # Правильная структура возвращаемого значения - массив из двух элементов
        allow(SportNotifyBot::Parsers::FlashscoreParser).to receive(:parse)
          .with(max_length: 4096)
          .and_return([tennis_data, 2100])

        sports_data = [
          "<b>Футбол, Россия. Премьер-лига 2023/2024. 24 тур</b>",
          "12:00 - <i>Оренбург (Россия)</i> – : – <i>ЦСКА (Россия)</i>"
        ]

        allow(SportNotifyBot::Parsers::SportsRuParser).to receive(:parse)
          .with(max_length: instance_of(Integer))
          .and_return([sports_data, 100])
      end

      it "limits tennis data to 10 matches" do
        result = SportNotifyBot::MessageBuilder.build_message

        # Добавим отладочный вывод
        puts "Результат с ограничением тенниса: #{result}"

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
# rubocop:enable Metrics/BlockLength
