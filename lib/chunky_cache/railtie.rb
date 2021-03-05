# frozen_string_literal: true

require_relative "view_helpers"

module ChunkyCache
  class Railtie < Rails::Railtie
    initializer "chunky_cache.view_helpers" do |app|
      ActiveSupport.on_load(:action_view) do
        self.class_eval do
          include ChunkyCache::ViewHelpers
        end
      end
    end
  end
end
