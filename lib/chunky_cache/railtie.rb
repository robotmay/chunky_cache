# frozen_string_literal: true

require_relative "view_helpers"

module ChunkyCache
  class Railtie < ::Rails::Railtie
    initializer "chunky_cache.view_helpers" do |app|
      self.class_eval do
        include ChunkyCache::ViewHelpers
      end
    end
  end
end
