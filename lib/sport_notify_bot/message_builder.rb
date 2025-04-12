# frozen_string_literal: true

module SportNotifyBot
  # Класс для сборки текстового сообщения из различных источников данных
  class MessageBuilder
    # Сборка сообщения из данных всех парсеров с приоритетом тенниса
    def self.build_message(max_length: SportNotifyBot.configuration.max_message_length)
      result = []
      total_length = 0
      first_section = true # Флаг для определения, нужно ли добавлять разделитель

      # 1. Парсим теннис с Flashscore (приоритет)
      tennis_result = parse_tennis(max_length, result, total_length, first_section)
      result = tennis_result[:result]
      total_length = tennis_result[:total_length]
      first_section = tennis_result[:first_section]

      # 2. Парсим Sports.ru, если осталось место
      remaining_length = max_length - total_length
      puts "Оставшаяся длина для Sports.ru: #{remaining_length}"

      sports_ru_result = parse_sports_ru(max_length, remaining_length, result, total_length, first_section)
      result = sports_ru_result[:result]
      total_length = sports_ru_result[:total_length]

      puts "Итоговая длина сообщения перед join: #{total_length}"
      result.join("\n")
    end

    private

    def self.parse_tennis(max_length, result, total_length, first_section)
      puts "Парсинг Flashscore (теннис)..."
      begin
        tennis_data, tennis_length = Parsers::FlashscoreParser.parse(max_length: max_length)
        if tennis_data.any? && tennis_length > 0 # Проверяем, что есть данные и длина > 0
          # Если данных тенниса слишком много, ограничим их до первых 10 матчей (или меньше)
          if tennis_length > max_length / 2
            puts "Теннис занимает много места. Ограничиваем до первых 10 матчей."
            # Первый элемент - обычно заголовок, его всегда оставляем
            header = tennis_data.shift
            # Ограничиваем количество матчей до 10
            matches = tennis_data.take(10)
            # Собираем обратно только заголовок и ограниченный список матчей
            tennis_data = [header] + matches
            # Пересчитываем занимаемую длину
            tennis_length = header.length + 1 + matches.sum { |match| match.length + 1 }
            puts "Теннис ограничен до #{matches.length} матчей (длина: #{tennis_length})."
          end

          puts "Добавляем данные Flashscore (длина: #{tennis_length})."
          result.concat(tennis_data)
          total_length += tennis_length
          first_section = false # Теннис был добавлен
        else
          puts "Нет данных от Flashscore или длина 0."
        end
      rescue StandardError => e
        puts "Ошибка при парсинге Flashscore: #{e.message}"
        # Можно добавить запись об ошибке в само сообщение, если нужно
        error_line = HtmlFormatter.bold(HtmlFormatter.escape("Теннис: Ошибка парсинга"))
        if total_length + error_line.length + 1 <= max_length
           result << error_line
           total_length += error_line.length + 1
           first_section = false
        end
      end

      { result: result, total_length: total_length, first_section: first_section }
    end

    def self.parse_sports_ru(max_length, remaining_length, result, total_length, first_section)
      if remaining_length > 1 # Нужно место хотя бы для разделителя (если нужен) и одной строки
        # Добавляем разделитель, если уже есть контент (теннис) и осталось место
        unless first_section
          separator = "\n" # Используем перенос строки как разделитель
          if total_length + separator.length <= max_length
            result << "" # Добавляем пустую строку для визуального разделения
            total_length += separator.length # Учитываем длину разделителя (1 символ новой строки)
            remaining_length = max_length - total_length # Обновляем оставшуюся длину
            puts "Добавлен разделитель. Новая оставшаяся длина: #{remaining_length}"
          else
            puts "Недостаточно места для разделителя."
            remaining_length = 0 # Места для разделителя нет, значит и для контента тоже
          end
        end

        if remaining_length > 0
          puts "Парсинг Sports.ru..."
          begin
            # Предполагаем, что SportsRuParser.parse возвращает [массив_строк, общая_длина]
            sports_ru_data, sports_ru_length = Parsers::SportsRuParser.parse(max_length: remaining_length)

            if sports_ru_data.any? && sports_ru_length > 0
              if sports_ru_length <= remaining_length
                puts "Добавляем данные Sports.ru (длина: #{sports_ru_length})."
                result.concat(sports_ru_data)
                total_length += sports_ru_length
                # first_section = false # Уже не нужно, т.к. это последний блок
              else
                # Если данные Sports.ru не помещаются полностью, добавляем столько, сколько поместится
                puts "Данные Sports.ru не помещаются полностью. Добавляем только то, что поместится."
                remaining_sport_ru_data = []
                added_length = 0

                # Проходим по каждой строке и добавляем, пока есть место
                sports_ru_data.each do |line|
                  line_length = line.length + 1 # +1 за перенос строки
                  if added_length + line_length <= remaining_length
                    remaining_sport_ru_data << line
                    added_length += line_length
                  else
                    break
                  end
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
