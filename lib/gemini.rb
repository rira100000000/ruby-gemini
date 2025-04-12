require "faraday"
require "faraday/multipart"
require "json"
require 'dotenv/load'

require_relative "gemini/version"
require_relative "gemini/http_headers"
require_relative "gemini/http"
require_relative "gemini/client"
require_relative "gemini/models"
require_relative "gemini/threads"
require_relative "gemini/messages"
require_relative "gemini/runs"
require_relative "gemini/embeddings"
require_relative "gemini/audio"
require_relative "gemini/files"
require_relative "gemini/images"
require_relative "gemini/response"
module Gemini
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class AuthenticationError < Error; end
  class APIError < Error; end
  class RateLimitError < Error; end
  class InvalidRequestError < Error; end
  
  class MiddlewareErrors < Faraday::Middleware
    def call(env)
      @app.call(env)
    rescue Faraday::Error => e
      raise e unless e.response.is_a?(Hash)
      Gemini.log_message("Gemini HTTP Error", e.response[:body], :error)
      raise e
    end
  end
  
  class Configuration
    attr_accessor :api_key,
                  :uri_base,
                  :log_errors,
                  :request_timeout,
                  :extra_headers
                  
    DEFAULT_URI_BASE = "https://generativelanguage.googleapis.com/v1beta".freeze
    DEFAULT_REQUEST_TIMEOUT = 120
    DEFAULT_LOG_ERRORS = false
    
    def initialize
      @api_key = nil
      @log_errors = DEFAULT_LOG_ERRORS
      @uri_base = DEFAULT_URI_BASE
      @request_timeout = DEFAULT_REQUEST_TIMEOUT
      @extra_headers = {}
    end
  end
  
  class << self
    attr_writer :configuration
    
    def configuration
      @configuration ||= Gemini::Configuration.new
    end
    
    def configure
      yield(configuration)
    end
    
    def log_message(prefix, message, level = :warn)
      return unless configuration.log_errors
      
      color = level == :error ? "\033[31m" : "\033[33m"
      logger = Logger.new($stdout)
      logger.formatter = proc do |_severity, _datetime, _progname, msg|
        "#{color}#{prefix} (spotted in ruby-gemini #{VERSION}): #{msg}\n\033[0m"
      end
      logger.send(level, message)
    end
  end
end