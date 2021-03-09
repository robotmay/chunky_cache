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
    # @param root_keys [*Object] key parts to apply to all `cache_chunk` calls.
    # @param expires_in [ActiveSupport::Duration, Integer] expiry time will be passed to the underlying store
    # @return [ActiveSupport::SafeBuffer]
    def chunky_cache(*root_keys, **cache_options)
      @chunky_key_blocks ||= {}
      blocks = @chunky_key_blocks[template_root_key] = {}

      @chunky_root_keys ||= {}
      @chunky_root_keys[template_root_key] = root_keys.unshift(template_root_key)

      # Capture the block, storing its output in a string
      big_ol_strang = capture do
        yield
      end

      # This probably shouldn't happen
      return if big_ol_strang.nil?

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

      big_ol_strang.html_safe
    end

    # Denote a cached chunk of markup. This captures the block
    # and instead returns just a placeholder string for replacement
    # at the end of the `chunky_cache` run.
    #
    # @param context [*Object] one or multiple objects which respond to `#cache_key` or convert to strings
    # @return [String] the placeholder key
    def cache_chunk(*context, &block)
      raise MissingChunkyCacheError if @chunky_key_blocks.nil?

      key = context.map { |k| k.try(:cache_key) || k.to_s }.unshift(@chunky_root_keys[template_root_key]).join(":")

      @chunky_key_blocks[template_root_key][key] = [block, context]

      return key
    end

    private

    # Returns the digest of the current template
    #
    # @return [String]
    def template_root_key
      @template_root_key ||= digest_path_from_template(@current_template)
    end
  end
end
