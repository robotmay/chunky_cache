# frozen_string_literal: true

require "spec_helper"

RSpec.describe ChunkyCache do
  it "has a version number" do
    expect(ChunkyCache::VERSION).not_to be nil
  end

  describe ApplicationHelper, type: :helper do
    let(:cache) { double("cache") }

    subject(:view) do
      Class.new.include(ChunkyCache::ViewHelpers)
    end

    before do
      allow(Rails).to receive(:cache).and_return(cache)
      allow(cache).to receive(:fetch_multi) { { "beercan:12345:test_key" => "substitute value" } }
      allow(helper).to receive(:reset_memory_cache).and_return(nil)
      allow(helper).to receive(:template_root_key).and_return("beercan:12345")
    end

    describe "#chunky_cache" do
      subject do
        helper.chunky_cache(expires_in: 10.minutes) do
          helper.cache_chunk(:test_key) do
            "test value"
          end
        end
      end

      it "establishes the chunk hash" do
        subject

        expect(helper.instance_variable_get(:@chunky_cache_store)).to be_a(Hash)
        expect(helper.instance_variable_get(:@chunky_cache_store)[:key_blocks]).to be_a(Hash)
      end

      it "queries the cache" do
        expect(cache).to receive(:fetch_multi).with("beercan:12345:test_key", expires_in: 10.minutes)

        subject
      end

      it "substitutes the block values" do
        expect(subject).to eq("substitute value")
      end

      it "caches by default" do
        subject
        
        expect(helper.instance_variable_get(:@chunky_cache_store)[:perform_caching]).to be(true)
      end

      it "caches if `if` conditional succeeds" do
        helper.chunky_cache(expires_in: 10.minutes, if: -> { true }) {}

        expect(helper.instance_variable_get(:@chunky_cache_store)[:perform_caching]).to be(true)
      end

      it "doesn't cache if `if` conditional fails" do
        helper.chunky_cache(expires_in: 10.minutes, if: -> { false }) {}

        expect(helper.instance_variable_get(:@chunky_cache_store)[:perform_caching]).to be(false)
      end

      it "caches if `unless` conditional succeeds" do
        helper.chunky_cache(expires_in: 10.minutes, unless: -> { false }) {}

        expect(helper.instance_variable_get(:@chunky_cache_store)[:perform_caching]).to be(true)
      end

      it "doesn't cache if `unless` conditional fails" do
        helper.chunky_cache(expires_in: 10.minutes, unless: -> { true }) {}

        expect(helper.instance_variable_get(:@chunky_cache_store)[:perform_caching]).to be(false)
      end
    end

    describe "#cache_chunk" do
      subject do
        helper.cache_chunk(:test_key) do
          "test value"
        end
      end

      context "key blocks established" do
        before do
          helper.instance_variable_set(:@chunky_cache_store, { key_blocks: {}, perform_caching: true })
        end

        it "returns the key" do
          expect(subject).to eq("beercan:12345:test_key")
        end

        it "stores the key and block in memory" do
          subject

          expect(helper.instance_variable_get(:@chunky_cache_store)[:key_blocks]["beercan:12345:test_key"]).to_not be_nil
        end

        it "supplies the context back to the block" do
          helper.cache_chunk(:test, :keys) do |first, second|
            expect(first).to eq(:test)
            expect(second).to eq(:keys)
          end
        end
      end

      context "no key blocks established" do
        before do
          helper.instance_variable_set(:@chunky_cache_store, nil)
        end

        it "renders the block immediately" do
          expect(subject).to eq("test value")
        end
      end

      context "caching is disabled" do
        before do
          helper.instance_variable_set(:@chunky_cache_store, { key_blocks: {}, perform_caching: false })
        end

        it "renders the block immediately" do
          expect(subject).to eq("test value")
        end
      end
    end
  end

  describe ArticlesController, type: :controller do
    render_views

    describe "content" do
      before do
        get :index
      end

      it "returns successfully" do
        expect(response).to have_http_status(:ok)
      end

      it "includes uncached data" do
        expect(response.body).to include("This title isn't cached")
        expect(response.body).to include("No wait, it was...")
      end

      it "includes cached data" do
        expect(response.body).to include("But this one is")
        expect(response.body).to include("chunky")
        expect(response.body).to include("beercan")
        expect(response.body).to include("probably")
      end

      it "renders cache calls in a loop correctly" do
        %w(cartoon fox tribute act).each do |word|
          expect(response.body).to include("<li>#{word}</li>")
        end
      end
    end

    describe "cache store" do
      let(:index_hash)   { "111849734f3c3a16b00439f9cc6a5a1c" }
      let(:partial_hash) { "277f6a046819c38de176f435dd15c5fb" }
      let(:keys) do
        [
          "articles/index:#{index_hash}:h2",
          "articles/index:#{index_hash}:cartoon",
          "articles/index:#{index_hash}:fox",
          "articles/index:#{index_hash}:tribute",
          "articles/index:#{index_hash}:act",
          "articles/index:#{index_hash}:chunky_whatsit",
          "articles/_beercan:#{partial_hash}:chunky:revelation",
          "articles/_beercan:#{partial_hash}:beercan:revelation",
          "articles/_beercan:#{partial_hash}:probably:revelation",
          "articles/index:#{index_hash}:ordering_test"
        ]

      it "only calls the cache once with all keys" do
        expect(Rails.cache).to receive(:fetch_multi).once.with(
          *keys,
          { expires_in: 10.minutes }
        ).and_call_original

        get :index
      end

      it "doesn't include the keys in the response" do
        get :index

        keys.each do |key|
          expect(response.body).to_not include(key)
        end
      end
    end
  end
end
