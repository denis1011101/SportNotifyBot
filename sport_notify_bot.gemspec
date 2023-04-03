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
  spec.required_ruby_version = ">= 3.1.3"

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

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
