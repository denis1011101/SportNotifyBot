# SportNotifyBot

A Ruby gem that fetches sports match data from popular sports websites (sports.ru and flashscore.com) and sends formatted notifications to Telegram channels or chats.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sport_notify_bot'
$ bundle install
$ gem install sport_notify_bot
```

## Configuration

Create a .env file in your project root with the following variables:

```ruby
TOKEN=your_telegram_bot_token
CHAT_ID=your_telegram_chat_id
```

You can also create a configuration file:

```ruby
SportNotifyBot.configure do |config|
  config.token = "your_telegram_bot_token"  # Optional if set in .env
  config.chat_id = "your_telegram_chat_id"  # Optional if set in .env
  # Custom HTTP headers if needed
  config.http_headers = {
    'User-Agent' => 'Your custom user agent'
  }
end
```

## Usage

Command Line
Run the bot to send sports notifications to your configured Telegram chat:

```ruby
$ sport_notify_bot send
```

View version information:

```ruby
$ sport_notify_bot version
```

In Your Code

```ruby
require 'sport_notify_bot'

# Configure if needed
SportNotifyBot.configure do |config|
  config.token = ENV["TELEGRAM_BOT_TOKEN"]
  config.chat_id = ENV["TELEGRAM_CHAT_ID"]
end

# Send sports notifications to Telegram
SportNotifyBot.run
```

## Features

- Fetches football, basketball, hockey, tennis and other sports matches data
- Tennis matches are parsed from flashscore.com for better accuracy
- Formats data with proper HTML for Telegram (bold, italic)
- Handles message length limitations (max 4096 characters)
- Provides proper error handling for network issues
- Customizable HTTP headers to avoid blocking

## Development

After checking out the repo, run setup to install dependencies. Then, run rake test to run the tests. You can also run console for an interactive prompt.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/sport_notify_bot. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/sport_notify_bot/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the SportNotifyBot project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/sport_notify_bot/blob/master/CODE_OF_CONDUCT.md).
