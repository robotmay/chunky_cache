# chunky_cache

This gem does weird things with Rails caching. Well, one weird thing. Have you ever wanted to perform multiple cache calls on a single view, but realised that this gets quite expensive in terms of network calls to your cache? Fret no more!

chunky_cache adds two Rails helpers which mess with the rendering order, allowing you to make multiple cache calls _but only execute one actual cache query_. It does this by capturing the view output inside the `chunky_cache` and `cache_chunk` helpers. These are named poorly and confusingly.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'chunky_cache'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install chunky_cache

## Usage

```erb
<%= chunky_cache(expires_in: 10.minutes) do %>
  <h1>Something not cached</h1>

  <p>
    <%= cache_chunk(:important_message, current_user) do %>
      <strong>This is very important, <%= current_user.name %>!</strong>
    <% end %>

    <%= cache_chunk(:the_actual_message) do %>
      <oblique>No, really</oblique>
    <% end %>
  </p>

  <%= cache_chunk(:footer) do %>
    <p>Fin.</p>
  <% end %>
<% end %>
```

This will execute only one call to your cache store, using `Rails.cache.fetch_multi`.

When using `cache_chunk` inside a loop, use its ability to pass the key components to the block
to persist the context (i.e. it'll be super borked if you don't do this):

```slim
  - for article in @articles
    = cache_chunk(article) do |article|
      h1= article.title
```

`cache_chunk` calls inside partials rendered inside the main `chunky_cache` call will also be picked up, this allows you to execute one network request for multiple chunks inside multiple view renders, e.g.

```slim
= chunky_cache(expires_in: 1.hour) do
  = render partial: "foxes", collection: @foxes

# Then inside _foxes.html.slim

= chunky_cache(expires_in: 1.hour) do # this will defer to the parent call, and isn't necessary
  = cache_chunk(fox) do |fox|
    = "Hello #{fox}"
```

## How does it work?

The helpers use Rails' built-in helper `capture` to consume the contents of their blocks and turn them into strings. `chunky_cache` does this immediately, and returns the final output after mixing everything together. But `cache_chunk` doesn't execute its block, instead storing it in an instance variable established by `chunky_cache`, and it then returns a cache key string. At this point the template is thus half-complete, with sections missing and only weird strings in their place.

`chunky_cache` then performs a cache multi-fetch, passing in all the keys it knows about. For any missing keys, the block captured by `cache_chunk` is executed and returned to the cache. The mix of cached/non-cached chunks are then reinserted into the main block content, replacing the key placeholders. A final compiled string is then returned.

## Why is this useful?

If you run `memcached` as your cache store on the same server as your Rails app, this gem is probably not very useful. Where it shines, however, is when network latency becomes more expensive than what you are caching. It allows you to cache lots of little chunks of markup, with different cache keys, and expend only one network request to fetch it. This allows you to start caching really trivial parts of templates that would never be worth caching normally; like caching individual navigation links in a menu, with active/inactive states, rather than caching the whole menu for each state. You can break up your larger caches into small sections with different keys, allowing parts of a cache to contain user-specific data but sharing generic data for everyone. This can be a useful cache storage size optimisation.

## Contributing

Please feel free to submit bug reports or merge requests. Don't use singlequotes in Ruby or you'll make me mad.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
