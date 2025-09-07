# SportNotifyBot

A Ruby gem that fetches sports match data from popular sports websites (sports.ru and flashscore.com) and sends formatted notifications to Telegram channels or chats.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sport_notify_bot'
$ bundle install
$ gem install sport_notify_bot
```

Browser Installation
For parsing Flashscore data, you'll need Chrome or Chromium browser installed:

On Ubuntu/Debian:
```
$ sudo apt-get install chromium-browser
```

The gem will automatically detect the browser location, or you can specify it manually in the .env file with the BROWSER_PATH variable

## Configuration

Create a .env file in your project root with the following variables:

```ruby
TOKEN=your_telegram_bot_token
CHAT_ID=your_telegram_chat_id
BROWSER_PATH=/path/to/chrome/or/chromium  # Optional, auto-detected if not specified
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
- Tennis matches are prioritized and parsed from Flashscore for better accuracy
- Formats data with proper HTML for Telegram (bold, italic)
- Smart message length management:
- If message is too large, tennis data is limited to 10 matches
- Remaining space is used for other sports data
- Handles message length limitations (max 4096 characters)
- Provides proper error handling for network issues
- Customizable HTTP headers to avoid blocking
- Automatic Chrome/Chromium browser detection for Flashscore parsing

## Structure

The gem is organized into several components:

- **Parsers**: Contains specialized parsers for different sports websites
    - FlashscoreParser: Parses tennis data from Flashscore
    - SportsRuParser: Parses various sports data from Sports.ru
- **MessageBuilder**: Builds the message from different data sources
- **MessageFormatter**: Handles message formatting and truncation
- **TelegramSender**: Sends the formatted message to Telegram

## Development

After checking out the repo, run setup to install dependencies. Then, run rake test to run the tests. You can also run console for an interactive prompt.

## Deployment / CI

- CI image: built by `.github/workflows/build_image.yml` and pushed to
  `ghcr.io/<owner>/sport-notify-bot-ci:latest`.
- Scheduler: `.github/workflows/daily.yml` pulls the CI image and runs the bot.

Required repository Secrets (Settings → Secrets and variables → Actions)
- TELEGRAM_TOKEN — Telegram bot token (e.g. 123456:ABC...).
- TELEGRAM_CHAT_ID — target chat id or `@channel`.

Optional (only if GITHUB_TOKEN cannot push to GHCR)
- GHCR_PAT — personal access token with `packages:write`.

How to trigger
- Rebuild image: push to `main` touching `Dockerfile` or Actions → Build CI image → Run workflow.
- Run daily job manually: Actions → Daily Send → Run workflow.

Rebuild the CI image after changing `Dockerfile` or system/native dependencies (e.g. nokogiri).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/denis1011101/sport_notify_bot. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/denis1011101/sport_notify_bot/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the SportNotifyBot project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/denis1011101/sport_notify_bot/blob/master/CODE_OF_CONDUCT.md).
