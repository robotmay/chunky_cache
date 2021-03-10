# frozen_string_literal: true

module ChunkyCache
  module ViewHelpers
    # Begin an exciting cache block. This has to wrap
    # calls to `cache_chunk`. This will absorb the contents of the block,
    # allowing it to discover the `cache_chunk` calls, before multi-fetching
    # all keys and then reinserting the cached contents or blocks into
    # the correct places in the output.
    #
    # All keyword arguments are passed to the cache store,
    # but Rails only supports `expires_in` for `fetch_multi` anyway.
    #
    # @param expires_in [ActiveSupport::Duration, Integer] expiry time will be passed to the underlying store
    # @return [ActiveSupport::SafeBuffer]
    def chunky_cache(**cache_options)
      # Return if the memory cache is already established, as an outer run of
      # this method is in progress already
      return yield if memory_cache.present?

      establish_memory_cache(cache_options)

      blocks = memory_cache[:key_blocks]

      # Capture the block, storing its output in a string
      big_ol_strang = capture do
        yield
      end

      # This probably shouldn't happen
      return if big_ol_strang.nil?
    
      # Return if caching is disabled
      return big_ol_strang unless memory_cache[:perform_caching]

      # Now the cache blocks are populated and the placeholders in place,
      # we multi-fetch all the keys from the cache, or call the `cache_chunk` blocks
      # for missing values.
      chunks = Rails.cache.fetch_multi(*blocks.keys, **cache_options) do |missing_key|
        logger.debug("Chunk cache miss: #{missing_key}")

        capture do
          block, context = *blocks[missing_key]
          block.call(*context)
        end
      end

      # Then we replace the placeholders with our new compiled template data
      chunks.each do |key, chunk|
        logger.debug("Chunk key replacement: #{key}")

        big_ol_strang.gsub!(key, (chunk || ""))
      end

      reset_memory_cache

      big_ol_strang.html_safe
    end

    # Denote a cached chunk of markup. This captures the block
    # and instead returns just a placeholder string for replacement
    # at the end of the `chunky_cache` run.
    #
    # @param context [*Object] one or multiple objects which respond to `#cache_key` or convert to strings
    # @return [String] the placeholder key
    def cache_chunk(*context, &block)
      return block.call(*context) if memory_cache.nil? || !memory_cache[:perform_caching]

      key = context.map { |k| k.try(:cache_key) || k.to_s }.unshift(template_root_key).join(":")

      memory_cache[:key_blocks][key] = [block, context]

      return key
    end

    private

    def establish_memory_cache(cache_options)
      conditional_if = cache_options.delete(:if)&.call
      conditional_unless = cache_options.delete(:unless)&.call

      @chunky_cache_store = {
        key_blocks: {},
        perform_caching: (conditional_if == true || conditional_unless == false || true)
      }
    end

    def memory_cache
      @chunky_cache_store
    end

    def reset_memory_cache
      @chunky_cache_store = nil
    end

    # Returns the digest of the current template
    #
    # @return [String]
    def template_root_key
      digest_path_from_template(@current_template)
    end
  end
end
