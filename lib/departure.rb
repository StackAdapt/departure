require 'active_record'
require 'active_support/all'

require 'departure/version'
require 'departure/log_sanitizers/password_sanitizer'
require 'departure/runner'
require 'departure/cli_generator'
require 'departure/logger'
require 'departure/null_logger'
require 'departure/logger_factory'
require 'departure/configuration'
require 'departure/errors'
require 'departure/command'
require 'departure/migration'

require 'departure/railtie' if defined?(Rails)

# We need the OS not to buffer the IO to see pt-osc's output while migrating
$stdout.sync = true

module Departure
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  # Hooks Percona Migrator into Rails migrations by replacing the configured
  # database adapter
  def self.load
    ActiveRecord::Migrator.instance_eval do
      class << self
        alias_method(:original_migrate, :migrate)
      end

      # Checks whether arguments are being passed through PERCONA_ARGS when running
      # the db:migrate rake task
      #
      # @raise [ArgumentsNotSupported] if PERCONA_ARGS has any value
      def migrate(migrations_paths, target_version = nil, &block)
        raise ArgumentsNotSupported if ENV['PERCONA_ARGS'].present?
        original_migrate(migrations_paths, target_version, &block)
      end
    end

    ActiveRecord::Migration.class_eval do
      include Departure::Migration
    end
  end
end
