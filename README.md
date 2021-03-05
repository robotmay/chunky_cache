# chunky_cache

This gem does weird things with Rails caching. Well, one weird thing. Have you ever wanted to perform multiple cache calls on a single view, but realised that this gets quite expensive in terms of network calls to your cache? Fret no more!

chunky_cache adds two Rails helpers which mess with the rendering order, allowing you to make multiple cache calls _but only execute one actual cache query_. It does this by capturing the view output inside the `chunky_cache` and `cache_chunk` helpers. These are named poorly.

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
    <%= cache_chunk(:important_message, current_user) %>
      <strong>This is very important, <%= current_user.name %>!</strong>
    <% end %>

    <%= cache_chunk(:the_actual_message) %>
      <oblique>No, really</oblique>
    <% end %>
  </p>

  <%= cache_chunk(:footer) %>
    <p>Fin.</p>
  <% end %>
<% end %>
```

This will execute only one call to your cache store, using `Rails.cache.fetch_multi`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Please feel free to submit bug reports or merge requests. Don't use singlequotes in Ruby or you'll make me mad.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
