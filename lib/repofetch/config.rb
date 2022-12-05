# frozen_string_literal: true

require 'yaml'

class Repofetch
  # Utilities for managing config.
  class Config
    PATH = File.expand_path('.repofetch.yml', Dir.home)
    DEFAULT_CONFIG = File.read(File.expand_path('DEFAULT_CONFIG', __dir__))

    # Loads from config file.
    def self.load
      new(File.read(PATH))
    end

    # Loads from a config file if it exists. If it doesn't, it writes the config file,
    # then creates a default.
    def self.load!
      if File.exist?(PATH)
        self.load
      else
        File.write(PATH, DEFAULT_CONFIG)
        new(DEFAULT_CONFIG)
      end
    end

    # @param config_yaml [String] a YAML string
    def initialize(config_yaml = '')
      @config = YAML.safe_load(config_yaml, symbolize_names: true) || {}
    end

    def plugins
      @config[:plugins] || []
    end

    # Should emojis be shown
    def emojis?
      @config[:emojis].nil? || @config[:emojis]
    end

    def emojis=(emojis)
      @config[:emojis] = emojis
    end

    def [](key)
      @config[key]
    end
  end
end
