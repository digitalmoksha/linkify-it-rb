# linkify-it-rb

[![Gem Version](https://badge.fury.io/rb/linkify-it-rb.svg)](http://badge.fury.io/rb/linkify-it-rb)
[![Build Status](https://travis-ci.org/digitalmoksha/linkify-it-rb.svg?branch=master)](https://travis-ci.org/digitalmoksha/linkify-it-rb)

This gem is a port of the [linkify-it javascript package](https://github.com/markdown-it/linkify-it) by Vitaly Puzrin, that is used for the [markdown-it](https://github.com/markdown-it/markdown-it) package.

_Currently synced with linkify-it 3.0.0_

---

Links recognition library with full unicode support. Focused on high quality link pattern detection in plain text.  For use with both Ruby and RubyMotion.

__[Javascript Demo](http://markdown-it.github.io/linkify-it/)__

Features:

- Full unicode support, with astral characters
- International domain support
- Allows rules extension & custom normalizers


Install
-------

### Ruby

Add it to your project's `Gemfile`

	gem 'linkify-it-rb'

and run `bundle install`

### RubyMotion

Add it to your project's `Gemfile`

	gem 'linkify-it-rb'

Edit your `Rakefile` and add

	require 'linkify-it-rb'

and run `bundle install`

Usage examples
--------------

##### Example 1

```ruby
linkify = Linkify.new

# Reload full tlds list & add unofficial `.onion` domain.
linkify.tlds('onion', true)      # Add unofficial `.onion` domain
linkify.add('git:', 'http:')     # Add `git:` protocol as "alias"
linkify.add('ftp:', null)        # Disable `ftp:` protocol
linkify.set({fuzzyIP: true})     # Enable IPs in fuzzy links (without schema)

linkify.test('Site github.com!'))
=> true

linkify.match('Site github.com!'))
=> [#<Linkify::Match @schema="", @index=5, @lastIndex=15, @raw="github.com", @text="github.com", @url="github.com">]
```

##### Example 2. Add twitter mentions handler

```ruby
linkify.add('@', {
  validate: lambda do |text, pos, obj|
    tail = text.slice(pos..-1)
    if (!obj.re[:twitter])
      obj.re[:twitter] =  Regexp.new('^([a-zA-Z0-9_]){1,15}(?!_)(?=$|' + LinkifyRe::SRC_Z_P_CC + ')')
    end
    if (obj.re[:twitter] =~ tail)
      return 0 if (pos >= 2 && text[pos - 2] == '@')
      return tail.match(obj.re[:twitter])[0].length
    end
    return 0
  end,
  normalize: lambda do |m, obj|
    m.url = 'https://twitter.com/' + m.url.sub(/^@/, '')
  end
})
```


API
---

### LinkifyIt.new(schemas, options)

Creates new linkifier instance with optional additional schemas.

By default understands:

- `http(s)://...` , `ftp://...`, `mailto:...` & `//...` links
- "fuzzy" links and emails (google.com, foo@bar.com).

`schemas` is a Hash, where each key/value describes protocol/rule:

- __key__ - link prefix (usually, protocol name with `:` at the end, `skype:`
  for example). `linkify-it-rb` makes sure that prefix is not preceded with
  alphanumeric char.
- __value__ - rule to check tail after link prefix
  - _String_ - just alias to existing rule
  - _Hash_
    - _validate_ - either a `RegExp (start with `^`, and don't include the
      link prefix itself), or a validator block which, given arguments,
      _text_, _pos_, and _self_, returns the length of a match in _text_
      starting at index _pos_.  _pos_ is the index right after the link prefix.
      _self_ can be used to access the linkify object to cache data.
    - _normalize_ - optional block to normalize text & url of matched result
      (for example, for twitter mentions).

`options`:

- __fuzzyLink__ - recognize URL-s without `http(s)://` head. Default `true`.
- __fuzzyIP__ - allow IPs in fuzzy links above. Can conflict with some texts
  like version numbers. Default `false`.
- __fuzzyEmail__ - recognize emails without `mailto:` prefix. Default `true`.
- __---__ - set `true` to terminate link with `---` (if it's considered as long dash).


### .test(text)

Searches linkifiable pattern and returns `true` on success or `false` on fail.


### .pretest(text)

Quick check if link MAYBE can exist. Can be used to optimize more expensive
`.test` calls. Return `false` if link can not be found, `true` - if `.test`
call needed to know exactly.


### .testSchemaAt(text, name, offset)

Similar to `.test` but checks only specific protocol tail exactly at given
position. Returns length of found pattern (0 on fail).


### .match(text)

Returns `Array` of found link matches or nil if nothing found.

Each match has:

- __schema__ - link schema, can be empty for fuzzy links, or `//` for
  protocol-neutral  links.
- __index__ - offset of matched text
- __lastIndex__ - index of next char after mathch end
- __raw__ - matched text
- __text__ - normalized text
- __url__ - link, generated from matched text


### .tlds(list[, keepOld])

Load (or merge) new tlds list. These are needed for fuzzy links (without schema)
to avoid false positives. By default this algorithm uses:

- 2-letter root zones are ok.
- biz|com|edu|gov|net|org|pro|web|xxx|aero|asia|coop|info|museum|name|shop|рф are ok.
- encoded (`xn--...`) root zones are ok.

If that's not enough, you can reload defaults with more detailed zones list.

### .add(key, value)

Add a new schema to the schemas object.  As described in the constructor
definition, `key` is a link prefix (`skype:`, for example), and `value`
is a String to alias to another schema, or an Object with `validate` and
optionally `normalize` definitions.  To disable an existing rule, use
`.add(key, null)`.

### .set(options)

Override default options. Missed properties will not be changed.

## License

[MIT](https://github.com/digitalmoksha/linkify-it-rb/blob/master/LICENSE)
