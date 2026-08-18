# frozen_string_literal: true

module SportNotifyBot
  # Преобразование названия страны в эмодзи-флаг.
  #
  # Названия приходят из разных источников: Flashscore отдаёт их на английском,
  # Sports.ru — на русском. Преобразование делается только на выводе, чтобы
  # потребители текста (например, getcourt) получали готовые эмодзи.
  module CountryFlag # rubocop:disable Metrics/ModuleLength
    # Наднациональные и служебные значения, для которых флага нет
    NON_COUNTRIES = [
      "world", "europe", "international", "africa", "asia", "oceania",
      "south america", "north america", "мир", "европа", "международный",
      "международные", "африка", "азия", "океания", "южная америка",
      "северная америка"
    ].freeze

    # Флаги подразделений Великобритании кодируются тег-последовательностями
    SUBDIVISION_FLAGS = {
      "GB-ENG" => "\u{1F3F4}\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}",
      "GB-SCT" => "\u{1F3F4}\u{E0067}\u{E0062}\u{E0073}\u{E0063}\u{E0074}\u{E007F}",
      "GB-WLS" => "\u{1F3F4}\u{E0067}\u{E0062}\u{E0077}\u{E006C}\u{E0073}\u{E007F}"
    }.freeze

    ENGLISH_TO_ISO = {
      "algeria" => "DZ", "andorra" => "AD", "angola" => "AO", "argentina" => "AR",
      "armenia" => "AM", "australia" => "AU", "austria" => "AT", "azerbaijan" => "AZ",
      "bahrain" => "BH", "barbados" => "BB", "belarus" => "BY", "belgium" => "BE",
      "bolivia" => "BO", "bosnia and herzegovina" => "BA", "brazil" => "BR",
      "bulgaria" => "BG", "burkina faso" => "BF", "cameroon" => "CM", "canada" => "CA",
      "cape verde" => "CV", "chile" => "CL", "china" => "CN", "colombia" => "CO",
      "costa rica" => "CR", "croatia" => "HR", "cuba" => "CU", "curaçao" => "CW",
      "cyprus" => "CY", "czech republic" => "CZ", "czechia" => "CZ", "denmark" => "DK",
      "dominican republic" => "DO", "ecuador" => "EC", "egypt" => "EG",
      "el salvador" => "SV", "england" => "GB-ENG", "estonia" => "EE",
      "faroe islands" => "FO", "finland" => "FI", "france" => "FR", "gabon" => "GA",
      "georgia" => "GE", "germany" => "DE", "ghana" => "GH", "gibraltar" => "GI",
      "greece" => "GR", "guatemala" => "GT", "honduras" => "HN", "hong kong" => "HK",
      "hungary" => "HU", "iceland" => "IS", "india" => "IN", "indonesia" => "ID",
      "iran" => "IR", "iraq" => "IQ", "ireland" => "IE", "israel" => "IL",
      "italy" => "IT", "ivory coast" => "CI", "jamaica" => "JM", "japan" => "JP",
      "jordan" => "JO", "kazakhstan" => "KZ", "kenya" => "KE", "kuwait" => "KW",
      "latvia" => "LV", "lebanon" => "LB", "libya" => "LY", "liechtenstein" => "LI",
      "lithuania" => "LT", "luxembourg" => "LU", "malaysia" => "MY", "mali" => "ML",
      "malta" => "MT", "mexico" => "MX", "moldova" => "MD", "monaco" => "MC",
      "mongolia" => "MN", "montenegro" => "ME", "morocco" => "MA", "netherlands" => "NL",
      "new zealand" => "NZ", "nigeria" => "NG", "north macedonia" => "MK",
      "northern ireland" => "GB", "northern mariana islands" => "MP", "norway" => "NO",
      "oman" => "OM", "pakistan" => "PK", "panama" => "PA", "paraguay" => "PY",
      "peru" => "PE", "philippines" => "PH", "poland" => "PL", "portugal" => "PT",
      "puerto rico" => "PR", "qatar" => "QA", "romania" => "RO", "russia" => "RU",
      "san marino" => "SM", "saudi arabia" => "SA", "scotland" => "GB-SCT",
      "senegal" => "SN", "serbia" => "RS", "singapore" => "SG", "slovakia" => "SK",
      "slovenia" => "SI", "south africa" => "ZA", "south korea" => "KR",
      "spain" => "ES", "sweden" => "SE", "switzerland" => "CH", "syria" => "SY",
      "taiwan" => "TW", "thailand" => "TH", "tunisia" => "TN", "turkey" => "TR",
      "ukraine" => "UA", "united arab emirates" => "AE", "united kingdom" => "GB",
      "uruguay" => "UY", "usa" => "US", "uzbekistan" => "UZ", "venezuela" => "VE",
      "vietnam" => "VN", "wales" => "GB-WLS", "zambia" => "ZM", "zimbabwe" => "ZW"
    }.freeze

    RUSSIAN_TO_ISO = {
      "австралия" => "AU", "австрия" => "AT", "азербайджан" => "AZ", "албания" => "AL",
      "алжир" => "DZ", "ангола" => "AO", "андорра" => "AD", "англия" => "GB-ENG",
      "аргентина" => "AR", "армения" => "AM", "бахрейн" => "BH", "беларусь" => "BY",
      "белоруссия" => "BY", "бельгия" => "BE", "бенин" => "BJ", "болгария" => "BG",
      "боливия" => "BO", "босния" => "BA", "босния и герцеговина" => "BA",
      "ботсвана" => "BW", "бразилия" => "BR", "буркина-фасо" => "BF", "бурунди" => "BI",
      "великобритания" => "GB", "венгрия" => "HU", "венесуэла" => "VE", "вьетнам" => "VN",
      "габон" => "GA", "гаити" => "HT", "гайана" => "GY", "гамбия" => "GM", "гана" => "GH",
      "гватемала" => "GT", "гвинея" => "GN", "гвинея-бисау" => "GW", "германия" => "DE",
      "гибралтар" => "GI", "голландия" => "NL", "гондурас" => "HN", "гонконг" => "HK",
      "греция" => "GR", "грузия" => "GE", "дания" => "DK", "джибути" => "DJ",
      "доминиканская республика" => "DO", "др конго" => "CD", "египет" => "EG",
      "замбия" => "ZM", "зимбабве" => "ZW", "израиль" => "IL", "индия" => "IN",
      "индонезия" => "ID", "иордания" => "JO", "ирак" => "IQ", "иран" => "IR",
      "ирландия" => "IE", "исландия" => "IS", "испания" => "ES", "италия" => "IT",
      "кабо-верде" => "CV", "казахстан" => "KZ", "камерун" => "CM", "канада" => "CA",
      "катар" => "QA", "кения" => "KE", "кипр" => "CY", "киргизия" => "KG",
      "китай" => "CN", "колумбия" => "CO", "коморы" => "KM", "конго" => "CG",
      "корея" => "KR", "коста-рика" => "CR", "кот-д'ивуар" => "CI", "куба" => "CU",
      "кувейт" => "KW", "кыргызстан" => "KG", "кюрасао" => "CW", "латвия" => "LV",
      "лесото" => "LS", "либерия" => "LR", "ливан" => "LB", "ливия" => "LY",
      "литва" => "LT", "лихтенштейн" => "LI", "люксембург" => "LU", "маврикий" => "MU",
      "мавритания" => "MR", "мадагаскар" => "MG", "македония" => "MK", "малави" => "MW",
      "малайзия" => "MY", "мали" => "ML", "мальта" => "MT", "марокко" => "MA",
      "мексика" => "MX", "мозамбик" => "MZ", "молдавия" => "MD", "молдова" => "MD",
      "монако" => "MC", "монголия" => "MN", "намибия" => "NA", "нигер" => "NE",
      "нигерия" => "NG", "нидерланды" => "NL", "никарагуа" => "NI",
      "новая зеландия" => "NZ", "норвегия" => "NO", "оаэ" => "AE",
      "объединенные арабские эмираты" => "AE", "оман" => "OM", "пакистан" => "PK",
      "панама" => "PA", "парагвай" => "PY", "перу" => "PE", "польша" => "PL",
      "португалия" => "PT", "пуэрто-рико" => "PR", "россия" => "RU", "руанда" => "RW",
      "румыния" => "RO", "сальвадор" => "SV", "сан-марино" => "SM",
      "саудовская аравия" => "SA", "северная ирландия" => "GB",
      "северная корея" => "KP", "северная македония" => "MK", "сейшелы" => "SC",
      "сенегал" => "SN", "сербия" => "RS", "сингапур" => "SG", "сирия" => "SY",
      "словакия" => "SK", "словения" => "SI", "сомали" => "SO", "судан" => "SD",
      "суринам" => "SR", "сша" => "US", "сьерра-леоне" => "SL", "таджикистан" => "TJ",
      "таиланд" => "TH", "тайвань" => "TW", "танзания" => "TZ", "того" => "TG",
      "тринидад и тобаго" => "TT", "тунис" => "TN", "туркменистан" => "TM",
      "турция" => "TR", "уганда" => "UG", "узбекистан" => "UZ", "украина" => "UA",
      "уругвай" => "UY", "уэльс" => "GB-WLS", "фарерские острова" => "FO",
      "филиппины" => "PH", "финляндия" => "FI", "франция" => "FR", "хорватия" => "HR",
      "цар" => "CF", "чад" => "TD", "черногория" => "ME", "чехия" => "CZ",
      "чили" => "CL", "швейцария" => "CH", "швеция" => "SE", "шотландия" => "GB-SCT",
      "шри-ланка" => "LK", "эквадор" => "EC", "экваториальная гвинея" => "GQ",
      "эритрея" => "ER", "эстония" => "EE", "эсватини" => "SZ", "эфиопия" => "ET",
      "юар" => "ZA", "южная корея" => "KR", "ямайка" => "JM", "япония" => "JP"
    }.freeze

    ISO_BY_COUNTRY = ENGLISH_TO_ISO.merge(RUSSIAN_TO_ISO).freeze

    # Эмодзи-флаг по названию страны или nil, если страна неизвестна
    def self.for(country_name)
      key = normalize(country_name)
      return nil if key.empty? || NON_COUNTRIES.include?(key)

      iso = ISO_BY_COUNTRY[key]
      return nil unless iso

      from_iso(iso)
    end

    # Эмодзи-флаг по ISO-коду ("FR", "GB-ENG")
    def self.from_iso(iso)
      return SUBDIVISION_FLAGS[iso] if SUBDIVISION_FLAGS.key?(iso)

      iso.chars.map { |c| (0x1F1E6 + c.ord - "A".ord).chr("UTF-8") }.join
    end

    def self.normalize(country_name)
      country_name.to_s.strip.downcase.tr("ё", "е").gsub(/[\s ]+/, " ")
    end
  end
end
