# frozen_string_literal: true

require_relative "lib/sport_notify_bot/version"

Gem::Specification.new do |spec|
  spec.name = "sport_notify_bot"
  spec.version = SportNotifyBot::VERSION
  spec.authors = ["denis"]
  spec.email = ["denisdenis9331@gmail.com"]

  spec.summary = "bot for send notifications about sport matches"
  spec.description = "bot for send notifications about sport matches"
  spec.homepage = "https://www.github.com/"
  spec.license = "MIT"
  spec.required_ruby_version = "3.4.5"

  spec.metadata["allowed_push_host"] = "https://www.github.com/"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://www.github.com/"
  spec.metadata["changelog_uri"] = "https://www.github.com/"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "base64", "~> 0.2.0"
  spec.add_dependency "dotenv", "~> 3.1.8"
  spec.add_dependency "faraday", "~> 2.13.0"
  spec.add_dependency "ferrum", "~> 0.16"
  spec.add_dependency "nokogiri", ">= 1.15", "< 2.0"

  spec.add_development_dependency "rake", "~> 13.3.0"
  spec.add_development_dependency "rspec", "~> 3.13.0"
  spec.add_development_dependency "rubocop", "~> 1.75.2"
  spec.add_development_dependency "webmock", "~> 3.25.1"
end
