# frozen_string_literal: true

module SportNotifyBot
  # Класс для сборки текстового сообщения из различных источников данных
  class MessageBuilder # rubocop:disable Metrics/ClassLength
    # Сборка сообщения из данных всех парсеров с приоритетом тенниса
    def self.build_message(max_length: SportNotifyBot.configuration.max_message_length) # rubocop:disable Metrics/MethodLength
      result = []
      total_length = 0
      first_section = true

      tennis_result = parse_tennis(max_length, result, total_length, first_section)
      result = tennis_result[:result]
      total_length = tennis_result[:total_length]
      first_section = tennis_result[:first_section]

      remaining_length = max_length - total_length
      puts "Оставшаяся длина для Sports.ru: #{remaining_length}"

      sports_ru_result = parse_sports_ru(max_length, remaining_length, result, total_length, first_section)
      result = sports_ru_result[:result]
      total_length = sports_ru_result[:total_length]

      puts "Итоговая длина сообщения перед join: #{total_length}"
      result.join("\n")
    end

    def self.parse_tennis(max_length, result, total_length, first_section) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      puts "Парсинг Flashscore (теннис)..."
      begin
        raw_data = Parsers::FlashscoreParser.parse(max_length: max_length)
        # Дополнительная защита от неверного формата данных
        tennis_data = raw_data[0]
        tennis_length = raw_data[1]
        puts "FlashscoreParser вернул: tennis_data=#{tennis_data.class}(#{tennis_data.size}),
          tennis_length=#{tennis_length.class}(#{tennis_length})"

        if tennis_data.is_a?(Array) && !tennis_data.empty? &&
           tennis_length.is_a?(Integer) && tennis_length.positive?
          if tennis_length > max_length / 2
            puts "Теннис занимает много места. Ограничиваем до первых 10 матчей."
            header = tennis_data.shift
            matches = tennis_data.take(10)
            tennis_data = [header] + matches
            tennis_length = header.length + 1 + matches.sum { |match| match.length + 1 }
            puts "Теннис ограничен до #{matches.length} матчей (длина: #{tennis_length})."
          end

          puts "Добавляем данные Flashscore (длина: #{tennis_length})."
          result.concat(tennis_data)
          total_length += tennis_length
          first_section = false
        else
          puts "Нет данных от Flashscore или длина 0."
        end
      rescue StandardError => e
        puts "Ошибка при парсинге Flashscore: #{e.message}"
        error_line = HtmlFormatter.bold(HtmlFormatter.escape("Теннис: Ошибка парсинга"))
        if total_length + error_line.length + 1 <= max_length
          result << error_line
          total_length += error_line.length + 1
          first_section = false
        end
      end

      { result: result, total_length: total_length, first_section: first_section }
    end

    def self.parse_sports_ru(max_length, remaining_length, result, total_length, first_section) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/BlockNesting
      if remaining_length > 1
        unless first_section
          separator = "\n"
          if total_length + separator.length <= max_length
            result << ""
            total_length += separator.length
            remaining_length = max_length - total_length
            puts "Добавлен разделитель. Новая оставшаяся длина: #{remaining_length}"
          else
            puts "Недостаточно места для разделителя."
            remaining_length = 0
          end
        end

        if remaining_length.positive?
          puts "Парсинг Sports.ru..."
          begin
            sports_ru_data, sports_ru_length =
              Parsers::SportsRuParser.parse(max_length: remaining_length)

            if sports_ru_data.is_a?(Array) && !sports_ru_data.empty? &&
               sports_ru_length.is_a?(Integer) && sports_ru_length.positive?
              if sports_ru_length <= remaining_length
                puts "Добавляем данные Sports.ru (длина: #{sports_ru_length})."
                result.concat(sports_ru_data)
                total_length += sports_ru_length
              else
                puts "Данные Sports.ru не помещаются полностью. Добавляем только то, что поместится."
                remaining_sport_ru_data = []
                added_length = 0
                sports_ru_data.each do |line|
                  line_length = line.length + 1
                  break unless added_length + line_length <= remaining_length

                  remaining_sport_ru_data << line
                  added_length += line_length
                end

                if remaining_sport_ru_data.any?
                  puts "Добавляем частичные данные Sports.ru (длина: #{added_length})."
                  result.concat(remaining_sport_ru_data)
                  total_length += added_length
                else
                  puts "Не удалось добавить ни одной строки Sports.ru из-за ограничения размера."
                end
              end
            else
              puts "Нет данных от Sports.ru или длина 0."
            end
          rescue StandardError => e
            puts "Ошибка при парсинге Sports.ru: #{e.message}"
            error_line = HtmlFormatter.bold(HtmlFormatter.escape("Sports.ru: Ошибка парсинга"))
            if total_length + error_line.length + 1 <= max_length
              result << error_line
              total_length += error_line.length + 1
            end
          end
        else
          puts "Недостаточно места для данных Sports.ru после добавления разделителя (если был)."
        end
      else
        puts "Недостаточно места для Sports.ru и/или разделителя."
      end

      { result: result, total_length: total_length }
    end
  end
end
