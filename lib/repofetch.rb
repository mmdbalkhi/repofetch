# frozen_string_literal: true

require 'action_view'
require 'git'
require 'repofetch/config'
require 'repofetch/env'
require 'repofetch/exceptions'
require 'repofetch/theme'
require 'repofetch/util'

# Main class for repofetch
class Repofetch
  MAX_ASCII_WIDTH = 40
  MAX_ASCII_HEIGHT = 20
  DEFAULT_THEME = Theme.new.freeze
  @plugins = []

  class << self
    attr_reader :plugins
  end

  # Registers a plugin.
  #
  # @param [Plugin] plugin The plugin to register
  def self.register_plugin(plugin)
    @plugins << plugin
  end

  # Replaces an existing plugin. If the existing plugin does not exist,
  # then it registers the plugin instead.
  #
  # @param [Plugin] old The plugin to be replaced
  # @param [Plugin] new The new plugin
  def self.replace_or_register_plugin(old, new)
    index = @plugins.find_index(old)
    if index.nil?
      register_plugin(new)
    else
      @plugins[index] = new
      @plugins
    end
  end

  # Returns the plugin that should be used.
  # Raises a +Repofetch::NoPluginsError+ if no plugins are found.
  # Raises a +Repofetch::TooManyPluginsError+ if more than one plugin is found.
  #
  # @param [String] git An instance of +Git::Base+
  # @param [Array<String>] args The arguments passed to the program.
  # @param [Repofetch::Config] config The configuration to use.
  #
  # @returns [Plugin] A plugin to use.
  def self.get_plugin(git, args, config)
    available_plugins = @plugins.filter do |plugin_class|
      plugin_class.matches_repo?(git)
    rescue NoMethodError
      warn "#{plugin_class} Does not implement +matches_repo?+"
      false
    end
    raise NoPluginsError if available_plugins.empty?

    raise TooManyPluginsError if available_plugins.length > 1

    available_plugins[0].from_git(git, args, config)
  end

  # Gets the name of the default remote to use.
  #
  # Will try to pick "origin", but if that is not found then it will
  # pick the first one found, or nil if there aren't any available.
  #
  # @param [String] path The path to the repository.
  #
  # @returns [Git::Remote]
  def self.default_remote(git)
    remotes = git.remotes
    found_remote = remotes.find { |remote| remote.name == 'origin' }
    found_remote = remotes[0] if found_remote.nil?
    found_remote
  end

  # Just wrapper around +default_remote+ since this is likely the most common
  # use case (and it's easier than referencing the +Git::Remote+ docs to ensure
  # correct usage in each plugin).
  #
  # @param [String] path The path to the repository.
  #
  # @return [String]
  def self.default_remote_url(path)
    default_remote(path)&.url
  end

  # Base class for plugins.
  class Plugin
    # Plugin intializer arguments should come from the +from_git+ or +from_args+
    # class methods.
    def initialize(*) end

    # Registers this plugin class for repofetch.
    def self.register
      Repofetch.register_plugin(self)
    end

    # Tries to replace another plugin. An example use case might be if this plugin
    # extends another registered plugin.
    #
    # @param [Plugin] old The plugin to replace
    def self.replace_or_register(old)
      Repofetch.replace_or_register_plugin(old, self)
    end

    # Detects that this plugin should be used. Should be overridden by subclasses.
    #
    # An example implementation is checking if +Repofetch.default_remote_url+ matches
    # a regular expression.
    #
    # @param [Git::Base] _git The Git repository object
    def self.matches_repo?(_git)
      raise NoMethodError, 'matches_repo? must be overridden by the plugin subclass'
    end

    # This should use a git instance and call +Plugin.new+.
    #
    # @param [Git::Base] _git The Git repository object to use when calling +Plugin.new+.
    # @param [Array] _args The arguments to process.
    # @param [Config] _config The configuration loaded by the CLI.
    #
    # @returns [Plugin]
    def self.from_git(_git, _args, _config)
      raise NoMethodError, 'from_git must be overridden by the plugin subclass'
    end

    # This will receive an array of strings (e.g. +ARGV+) and call +Plugin.new+.
    #
    # @param [Array] _args The arguments to process.
    # @param [Config] _config The configuration loaded by the CLI.
    #
    # @returns [Plugin]
    def self.from_args(_args, _config)
      raise NoMethodError, 'from_args must be overridden by the plugin subclass'
    end

    # Gets the plugin's theme. Override to use a theme besides the default.
    def theme
      Repofetch::DEFAULT_THEME
    end

    # The ASCII to be printed alongside the stats.
    #
    # This should be overridden by the plugin subclass.
    # Should be within the bounds 40x20 (width x height).
    def ascii
      raise NoMethodError, 'ascii must be overridden by the plugin subclass'
    end

    # The header to show for the plugin.
    #
    # This should be overridden by the plugin subclass.
    # For example, "foo/bar @ GitHub".
    def header
      raise NoMethodError, 'header must be overridden by the plugin subclass'
    end

    # Creates the separator that appears underneath the header
    def separator
      '-' * Repofetch::Util.clean_s(header).length
    end

    def to_s
      zipped_lines.map do |ascii_line, stat_line|
        cleaned_ascii = Repofetch::Util.clean_s(ascii_line)
        styled_ascii = (ascii_line % theme.to_h) + theme.style(:reset)
        aligned_stat_line = "#{' ' * (MAX_ASCII_WIDTH + 5)}#{stat_line}"
        "#{styled_ascii}#{aligned_stat_line.slice(cleaned_ascii.length..)}\n"
      end.join
    end

    # An array of stats that will be displayed to the right of the ASCII art.
    #
    # @returns [Array<Stat>]
    def stats
      []
    end

    # Makes an array of stat lines, including the header and separator.
    def stat_lines
      [header, separator, *stats.map(&:to_s)]
    end

    # Zips ASCII lines with stat lines.
    #
    # If there are more of one than the other, than the zip will be padded with empty strings.
    def zipped_lines
      ascii_lines = ascii.lines.map(&:chomp)
      if ascii_lines.length > stat_lines.length
        ascii_lines.zip(stat_lines)
      else
        stat_lines.zip(ascii_lines).map(&:reverse)
      end.map { |ascii, stat| [ascii.to_s, stat.to_s] }
    end
  end

  # Base class for stats.
  class Stat
    attr_reader :label, :value, :emoji

    # Creates a stat
    #
    # @param [String] label The label of the stat
    # @param value The value of the stat
    # @param [String] emoji An optional emoji for the stat
    def initialize(label, value, emoji: nil, theme: nil)
      @label = label
      @value = value
      @emoji = emoji
      @theme = theme
    end

    def to_s
      "#{@emoji || ''}#{@theme.nil? ? @label : @theme.format(:bold, @label)}: #{format_value}"
    end

    # Formats the value
    #
    # This simply converts the value to a string, but can be overridden but
    # subclasses to affect +to_s+.
    def format_value
      @value.to_s
    end
  end

  # Timespan stat for "x units ago" stats.
  class TimespanStat < Stat
    include ActionView::Helpers::DateHelper

    # Formats the value as "x units ago".
    def format_value(now = nil)
      now = Time.now if now.nil?
      "#{distance_of_time_in_words(@value, now)} ago"
    end
  end

  def self.clear_plugins
    @plugins = []
  end
  private_class_method :clear_plugins
end