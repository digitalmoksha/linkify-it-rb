class Linkify
  include ::LinkifyRe
  
  attr_accessor   :__index__, :__last_index__, :__text_cache__, :__schema__, :__compiled__
  attr_accessor   :re, :bypass_normalizer
  
  # DON'T try to make PRs with changes. Extend TLDs with LinkifyIt.tlds() instead
  TLDS_DEFAULT = 'biz|com|edu|gov|net|org|pro|web|xxx|aero|asia|coop|info|museum|name|shop|рф'.split('|')
  
  DEFAULT_SCHEMAS = {
    'http:' => {
      validate: lambda do |text, pos, obj|
        tail = text.slice(pos..-1)

        if (!obj.re[:http])
          # compile lazily, because "host"-containing variables can change on tlds update.
          obj.re[:http] = Regexp.new('^\\/\\/' + LinkifyRe::SRC_AUTH + LinkifyRe::SRC_HOST_PORT_STRICT + LinkifyRe::SRC_PATH, 'i')
        end
        if obj.re[:http] =~ tail
          return tail.match(obj.re[:http])[0].length
        end
        return 0
      end
    },
    'https:' =>  'http:',
    'ftp:' =>    'http:',
    '//' =>      {
      validate: lambda do |text, pos, obj|
        tail = text.slice(pos..-1)

        if (!obj.re[:no_http])
          # compile lazily, becayse "host"-containing variables can change on tlds update.
          obj.re[:no_http] = Regexp.new('^' + LinkifyRe::SRC_AUTH + LinkifyRe::SRC_HOST_PORT_STRICT + LinkifyRe::SRC_PATH, 'i')
        end

        if (obj.re[:no_http] =~ tail)
          # should not be `://`, that protects from errors in protocol name
          return 0 if (pos >= 3 && text[pos - 3] == ':')
          return tail.match(obj.re[:no_http])[0].length
        end
        return 0
      end
    },
    'mailto:' => {
      validate: lambda do |text, pos, obj|
        tail = text.slice(pos..-1)

        if (!obj.re[:mailto])
          obj.re[:mailto] = Regexp.new('^' + LinkifyRe::SRC_EMAIL_NAME + '@' + LinkifyRe::SRC_HOST_STRICT, 'i')
        end
        if (obj.re[:mailto] =~ tail)
          return tail.match(obj.re[:mailto])[0].length
        end
        return 0
      end
    }
  }

  #------------------------------------------------------------------------------
  def escapeRE(str)
    return str.gsub(/[\.\?\*\+\^\$\[\]\\\(\)\{\}\|\-]/, "\\$&")
  end

  #------------------------------------------------------------------------------
  def resetScanCache
    @__index__      = -1
    @__text_cache__ = ''
  end

  #------------------------------------------------------------------------------
  def createValidator(re)
    return lambda do |text, pos, obj|
      tail = text.slice(pos..-1)

      (re =~ tail) ? tail.match(re)[0].length : 0
    end
  end

  #------------------------------------------------------------------------------
  def createNormalizer()
    return lambda do |match, obj|
      obj.normalize(match)
    end
  end

  # Schemas compiler. Build regexps.
  #
  #------------------------------------------------------------------------------
  def compile
    @re = { src_xn: LinkifyRe::SRC_XN }

    # Define dynamic patterns
    tlds = @__tlds__.dup
    tlds.push('[a-z]{2}') if (!@__tlds_replaced__)
    tlds.push(@re[:src_xn])

    @re[:src_tlds] = tlds.join('|')
    @re[:email_fuzzy]      = Regexp.new(LinkifyRe::TPL_EMAIL_FUZZY.gsub('%TLDS%', @re[:src_tlds]), true)
    @re[:link_fuzzy]       = Regexp.new(LinkifyRe::TPL_LINK_FUZZY.gsub('%TLDS%', @re[:src_tlds]), true)
    @re[:host_fuzzy_test]  = Regexp.new(LinkifyRe::TPL_HOST_FUZZY_TEST.gsub('%TLDS%', @re[:src_tlds]), true)

    #
    # Compile each schema
    #

    aliases = []

    @__compiled__ = {} # Reset compiled data

    schemaError = lambda do |name, val|
      raise Error, ('(LinkifyIt) Invalid schema "' + name + '": ' + val)
    end

    @__schemas__.each do |name, val|

      # skip disabled methods
      next if (val == nil)

      compiled = { validate: nil, link: nil }

      @__compiled__[name] = compiled

      if (val.is_a? Hash)
        if (val[:validate].is_a? Regexp)
          compiled[:validate] = createValidator(val[:validate])
        elsif (val[:validate].is_a? Proc)
          compiled[:validate] = val[:validate]
        else
          schemaError(name, val)
        end

        if (val[:normalize].is_a? Proc)
          compiled[:normalize] = val[:normalize]
        elsif (!val[:normalize])
          compiled[:normalize] = createNormalizer()
        else
          schemaError(name, val)
        end
        next
      end

      if (val.is_a? String)
        aliases.push(name)
        next
      end

      schemaError(name, val)
    end

    #
    # Compile postponed aliases
    #

    aliases.each do |an_alias|
      if (!@__compiled__[@__schemas__[an_alias]])
        # Silently fail on missed schemas to avoid errons on disable.
        # schemaError(an_alias, self.__schemas__[an_alias]);
      else
        @__compiled__[an_alias][:validate]  = @__compiled__[@__schemas__[an_alias]][:validate]
        @__compiled__[an_alias][:normalize] = @__compiled__[@__schemas__[an_alias]][:normalize]
      end
    end

    #
    # Fake record for guessed links
    #
    @__compiled__[''] = { validate: nil, normalize: createNormalizer }

    #
    # Build schema condition, and filter disabled & fake schemas
    #
    slist = @__compiled__.select {|name, val| name.length > 0 && !val.nil? }.keys.map {|str| escapeRE(str)}.join('|')

    # (?!_) cause 1.5x slowdown
    @re[:schema_test]   = Regexp.new('(^|(?!_)(?:>|' + LinkifyRe::SRC_Z_P_CC + '))(' + slist + ')', 'i')
    @re[:schema_search] = Regexp.new('(^|(?!_)(?:>|' + LinkifyRe::SRC_Z_P_CC + '))(' + slist + ')', 'ig')

    @re[:pretest]       = Regexp.new(
                              '(' + @re[:schema_test].source + ')|' +
                              '(' + @re[:host_fuzzy_test].source + ')|' + '@', 'i')

    #
    # Cleanup
    #

    resetScanCache
  end
    
  # Match result. Single element of array, returned by [[LinkifyIt#match]]
  #------------------------------------------------------------------------------
  class Match
    attr_accessor   :schema, :index, :lastIndex, :raw, :text, :url
    
    def initialize(obj, shift)
      start = obj.__index__
      endt  = obj.__last_index__
      text  = obj.__text_cache__.slice(start...endt)

      # Match#schema -> String
      #
      # Prefix (protocol) for matched string.
      @schema    = obj.__schema__.downcase

      # Match#index -> Number
      #
      # First position of matched string.
      @index     = start + shift

      # Match#lastIndex -> Number
      #
      # Next position after matched string.
      @lastIndex = endt + shift

      # Match#raw -> String
      #
      # Matched string.
      @raw       = text

      # Match#text -> String
      #
      # Notmalized text of matched string.
      @text      = text

      # Match#url -> String
      #
      # Normalized url of matched string.
      @url       = text
    end

    #------------------------------------------------------------------------------
    def self.createMatch(obj, shift)
      match = Match.new(obj, shift)
      obj.__compiled__[match.schema][:normalize].call(match, obj)
      return match
    end
  end



  # new LinkifyIt(schemas)
  # - schemas (Object): Optional. Additional schemas to validate (prefix/validator)
  #
  # Creates new linkifier instance with optional additional schemas.
  # Can be called without `new` keyword for convenience.
  #
  # By default understands:
  #
  # - `http(s)://...` , `ftp://...`, `mailto:...` & `//...` links
  # - "fuzzy" links and emails (example.com, foo@bar.com).
  #
  # `schemas` is an object, where each key/value describes protocol/rule:
  #
  # - __key__ - link prefix (usually, protocol name with `:` at the end, `skype:`
  #   for example). `linkify-it` makes shure that prefix is not preceeded with
  #   alphanumeric char and symbols. Only whitespaces and punctuation allowed.
  # - __value__ - rule to check tail after link prefix
  #   - _String_ - just alias to existing rule
  #   - _Object_
  #     - _validate_ - validator function (should return matched length on success),
  #       or `RegExp`.
  #     - _normalize_ - optional function to normalize text & url of matched result
  #       (for example, for @twitter mentions).
  #------------------------------------------------------------------------------
  def initialize(schemas = {})
    # if (!(this instanceof LinkifyIt)) {
    #   return new LinkifyIt(schemas);
    # }

    # Cache last tested result. Used to skip repeating steps on next `match` call.
    @__index__          = -1
    @__last_index__     = -1 # Next scan position
    @__schema__         = ''
    @__text_cache__     = ''

    @__schemas__        = {}.merge!(DEFAULT_SCHEMAS).merge!(schemas)
    @__compiled__       = {}

    @__tlds__           = TLDS_DEFAULT
    @__tlds_replaced__  = false

    @re                 = {}

    @bypass_normalizer  = false   # only used in testing scenarios

    compile
  end


  # chainable
  # LinkifyIt#add(schema, definition)
  # - schema (String): rule name (fixed pattern prefix)
  # - definition (String|RegExp|Object): schema definition
  #
  # Add new rule definition. See constructor description for details.
  #------------------------------------------------------------------------------
  def add(schema, definition)
    @__schemas__[schema] = definition
    compile
    return self
  end


  # LinkifyIt#test(text) -> Boolean
  #
  # Searches linkifiable pattern and returns `true` on success or `false` on fail.
  #------------------------------------------------------------------------------
  def test(text)
    # Reset scan cache
    @__text_cache__ = text
    @__index__      = -1

    return false if (!text.length)
    
    # try to scan for link with schema - that's the most simple rule
    if @re[:schema_test] =~ text
      re = @re[:schema_search]
      lastIndex = 0
      while ((m = re.match(text, lastIndex)) != nil)
        lastIndex = m.end(0)
        len       = testSchemaAt(text, m[2], lastIndex)
        if len > 0
          @__schema__     = m[2]
          @__index__      = m.begin(0) + m[1].length
          @__last_index__ = m.begin(0) + m[0].length + len
          break
        end
      end
    end

    # guess schemaless links
    if (@__compiled__['http:'])
      tld_pos = text.index(@re[:host_fuzzy_test])
      if !tld_pos.nil?
        # if tld is located after found link - no need to check fuzzy pattern
        if (@__index__ < 0 || tld_pos < @__index__)
          if ((ml = text.match(@re[:link_fuzzy])) != nil)

            shift = ml.begin(0) + ml[1].length

            if (@__index__ < 0 || shift < @__index__)
              @__schema__     = ''
              @__index__      = shift
              @__last_index__ = ml.begin(0) + ml[0].length
            end
          end
        end
      end
    end

    # guess schemaless emails
    if (@__compiled__['mailto:'])
      at_pos = text.index('@')
      if !at_pos.nil?
        # We can't skip this check, because this cases are possible:
        # 192.168.1.1@gmail.com, my.in@example.com
        if ((me = text.match(@re[:email_fuzzy])) != nil)

          shift = me.begin(0) + me[1].length
          nextc = me.begin(0) + me[0].length

          if (@__index__ < 0 || shift < @__index__ ||
              (shift == @__index__ && nextc > @__last_index__))
            @__schema__     = 'mailto:'
            @__index__      = shift
            @__last_index__ = nextc
          end
        end
      end
    end

    return @__index__ >= 0
  end


  # LinkifyIt#pretest(text) -> Boolean
  #
  # Very quick check, that can give false positives. Returns true if link MAY BE
  # can exists. Can be used for speed optimization, when you need to check that
  # link NOT exists.
  #------------------------------------------------------------------------------
  def pretest(text)
    return !(@re[:pretest] =~ text).nil?
  end


  # LinkifyIt#testSchemaAt(text, name, position) -> Number
  # - text (String): text to scan
  # - name (String): rule (schema) name
  # - position (Number): text offset to check from
  #
  # Similar to [[LinkifyIt#test]] but checks only specific protocol tail exactly
  # at given position. Returns length of found pattern (0 on fail).
  #------------------------------------------------------------------------------
  def testSchemaAt(text, schema, pos)
    # If not supported schema check requested - terminate
    if (!@__compiled__[schema.downcase])
      return 0
    end
    return @__compiled__[schema.downcase][:validate].call(text, pos, self)
  end


  # LinkifyIt#match(text) -> Array|null
  #
  # Returns array of found link descriptions or `null` on fail. We strongly suggest
  # to use [[LinkifyIt#test]] first, for best speed.
  #
  # ##### Result match description
  #
  # - __schema__ - link schema, can be empty for fuzzy links, or `//` for
  #   protocol-neutral  links.
  # - __index__ - offset of matched text
  # - __lastIndex__ - index of next char after mathch end
  # - __raw__ - matched text
  # - __text__ - normalized text
  # - __url__ - link, generated from matched text
  #------------------------------------------------------------------------------
  def match(text)
    shift  = 0
    result = []

    # Try to take previous element from cache, if .test() called before
    if (@__index__ >= 0 && @__text_cache__ == text)
      result.push(Match.createMatch(self, shift))
      shift = @__last_index__
    end

    # Cut head if cache was used
    tail = shift ? text.slice(shift..-1) : text

    # Scan string until end reached
    while (self.test(tail))
      result.push(Match.createMatch(self, shift))

      tail   = tail.slice(@__last_index__..-1)
      shift += @__last_index__
    end

    if (result.length)
      return result
    end

    return nil
  end


  # chainable
  # LinkifyIt#tlds(list [, keepOld]) -> this
  # - list (Array): list of tlds
  # - keepOld (Boolean): merge with current list if `true` (`false` by default)
  #
  # Load (or merge) new tlds list. Those are user for fuzzy links (without prefix)
  # to avoid false positives. By default this algorythm used:
  #
  # - hostname with any 2-letter root zones are ok.
  # - biz|com|edu|gov|net|org|pro|web|xxx|aero|asia|coop|info|museum|name|shop|рф
  #   are ok.
  # - encoded (`xn--...`) root zones are ok.
  #
  # If list is replaced, then exact match for 2-chars root zones will be checked.
  #------------------------------------------------------------------------------
  def tlds(list, keepOld)
    list = list.is_a?(Array) ? list : [ list ]

    if (!keepOld)
      @__tlds__ = list.dup
      @__tlds_replaced__ = true
      compile
      return self
    end

    @__tlds__ = @__tlds__.concat(list).sort.uniq.reverse

    compile
    return self
  end

  # LinkifyIt#normalize(match)
  #
  # Default normalizer (if schema does not define it's own).
  #------------------------------------------------------------------------------
  def normalize(match)
    return if @bypass_normalizer
    
    # Do minimal possible changes by default. Need to collect feedback prior
    # to move forward https://github.com/markdown-it/linkify-it/issues/1

    match.url = 'http://' + match.url if !match.schema

    if (match.schema == 'mailto:' && !(/^mailto\:/i =~ match.url))
      match.url = 'mailto:' + match.url
    end
  end

end