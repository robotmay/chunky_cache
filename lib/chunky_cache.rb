# frozen_string_literal: true

require "rails"
require "chunky_cache/version"
require "chunky_cache/railtie"

module ChunkyCache
  class Error < StandardError; end
  class MissingChunkyCacheError < Error; end
end
