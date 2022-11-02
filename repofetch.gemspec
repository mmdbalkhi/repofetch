# frozen_string_literal: true

LONG_DESCRIPTION = 'Fetches repository stats, like onefetch, but with a focus on the remote\'s stats'

Gem::Specification.new do |spec|
  spec.name                               = 'repofetch'
  spec.version                            = '0.4.0'
  spec.authors                            = ['Spenser Black']

  spec.summary                            = 'A plugin-based tool to fetch remote repository stats'
  spec.description                        = LONG_DESCRIPTION

  spec.homepage                           = 'https://github.com/spenserblack/repofetch'
  spec.license                            = 'MIT'

  spec.required_ruby_version              = Gem::Requirement.new('>= 2.7.0')

  spec.metadata['homepage_uri']           = spec.homepage
  spec.metadata['source_code_uri']        = 'https://github.com/spenserblack/repofetch'

  spec.files                              = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.bindir                             = 'exe'
  spec.executables                        = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths                      = ['lib']

  spec.metadata['rubygems_mfa_required']  = 'true'

  spec.metadata['github_repo']            = 'ssh://github.com/spenserblack/repofetch'

  # TODO: Really seems like overkill to install this just for distance_of_time_in_words
  spec.add_runtime_dependency 'actionview', '~> 7.0', '>= 7.0.4'

  spec.add_runtime_dependency 'git', '~> 1.12'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.11'
  spec.add_development_dependency 'rubocop', '~> 1.36'
  spec.add_development_dependency 'rubocop-rake', '~> 0.6'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.13'
  spec.add_development_dependency 'simplecov', '~> 0.21'
  spec.add_development_dependency 'simplecov-cobertura', '~> 2.1'
end
