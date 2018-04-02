fixture_dir  = File.join(File.dirname(__FILE__), 'fixtures')

#------------------------------------------------------------------------------
describe 'links' do

  l = Linkify.new({}, {fuzzyIP: true})
  l.bypass_normalizer = true    # kill the normalizer

  skipNext  = false
  linkfile  = File.join(fixture_dir, 'links.txt')
  lines     = File.read(linkfile).split(/\r?\n/)
  lines.each_with_index do |line, idx|
    if skipNext
      skipNext = false
      next
    end

    line      = line.sub(/^%.*/, '')
    next_line = (lines[idx + 1] || '').sub(/^%.*/, '')

    next if line.strip.empty?

    if !next_line.strip.empty?

      it "line #{idx + 1}" do
        expect(l.pretest(line)).to eq true        # "(pretest failed in `#{line}`)"
        expect(l.test("\n#{line}\n")).to eq true  # "(link not found in `\n#{line}\n`)"
        expect(l.test(line)).to eq true           # "(link not found in `#{line}`)"
        expect(l.match(line)[0].url).to eq next_line
      end

      skipNext = true

    else

      it "line #{idx + 1}" do
        expect(l.pretest(line)).to eq true        # "(pretest failed in `#{line}`)"
        expect(l.test("\n#{line}\n")).to eq true  # "(link not found in `\n#{line}\n`)"
        expect(l.test(line)).to eq true           # "(link not found in `#{line}`)"
        expect(l.match(line)[0].url).to eq line
      end
    end
  end

end


#------------------------------------------------------------------------------
describe 'not links' do

  l = Linkify.new
  l.bypass_normalizer = true    # kill the normalizer

  linkfile  = File.join(fixture_dir, 'not_links.txt')
  lines     = File.read(linkfile).split(/\r?\n/)
  lines.each_with_index do |line, idx|
    line = line.sub(/^%.*/, '')

    next if line.strip.empty?

    it "line #{idx + 1}" do
      expect(l.test(line)).not_to eq true
    end
  end

end

#------------------------------------------------------------------------------
describe 'API' do

  #------------------------------------------------------------------------------
  it 'extend tlds' do
    l = Linkify.new

    expect(l.test('google.myroot')).to_not eq true

    l.tlds('myroot', true)

    expect(l.test('google.myroot')).to eq true
    expect(l.test('google.xyz')).to_not eq true

    # TODO this is some other package of tlds which we don't have
    # https://github.com/stephenmathieson/node-tlds
    # instead we should be using Public Suffix List
    # https://github.com/weppos/publicsuffix-ruby
    # l.tlds(require('tlds'));
    # assert.ok(l.test('google.xyz'));
    # assert.notOk(l.test('google.myroot'));
  end


  #------------------------------------------------------------------------------
  it 'add rule as regexp, with default normalizer' do
    l = Linkify.new.add('my:', {validate: /^\/\/[a-z]+/} )

    match = l.match('google.com. my:// my://asdf!')

    expect(match[0].text).to eq 'google.com'
    expect(match[1].text).to eq 'my://asdf'
  end

  #------------------------------------------------------------------------------
  it 'add rule with normalizer' do
    l = Linkify.new.add('my:', {
      validate: /^\/\/[a-z]+/,
      normalize: lambda do |m, obj|
        m.text = m.text.sub(/^my:\/\//, '').upcase
        m.url  = m.url.upcase
      end
    })

    match = l.match('google.com. my:// my://asdf!')

    expect(match[1].text).to eq 'ASDF'
    expect(match[1].url).to eq 'MY://ASDF'
  end

  #------------------------------------------------------------------------------
  it 'disable rule' do
    l = Linkify.new

    expect(l.test('http://google.com')).to eq true
    expect(l.test('foo@bar.com')).to eq true
    l.add('http:', nil)
    l.add('mailto:', nil)
    expect(l.test('http://google.com')).to eq false
    expect(l.test('foo@bar.com')).to eq false
  end

  #------------------------------------------------------------------------------
  it 'add bad definition' do
    l = Linkify.new

    expect {
      l.add('test:', [])
    }.to raise_error(StandardError)

    l = Linkify.new

    expect {
      l.add('test:', {validate: []})
    }.to raise_error(StandardError)

    l = Linkify.new

    expect {
      l.add('test:', {validate: []})
    }.to raise_error(StandardError)

    expect {
      l.add('test:', {
        validate: lambda { return false },
        normalize: 'bad'
      })
    }.to raise_error(StandardError)
  end


  #------------------------------------------------------------------------------
  it 'test at position' do
    l = Linkify.new
    expect(l.testSchemaAt('http://google.com', 'http:', 5) > 0).to eq true
    expect(l.testSchemaAt('http://google.com', 'HTTP:', 5) > 0).to eq true
    expect(l.testSchemaAt('http://google.com', 'http:', 6) > 0).to eq false
    expect(l.testSchemaAt('http://google.com', 'bad_schema:', 6) > 0).to eq false
  end

  #------------------------------------------------------------------------------
  it 'correct cache value' do
    l     = Linkify.new
    match = l.match('.com. http://google.com google.com ftp://google.com')

    expect(match[0].text).to eq 'http://google.com'
    expect(match[1].text).to eq 'google.com'
    expect(match[2].text).to eq 'ftp://google.com'
  end

  #------------------------------------------------------------------------------
  it 'normalize' do
    l = Linkify.new
    m = l.match('mailto:foo@bar.com')[0]

    # assert.equal(m.text, 'foo@bar.com');
    expect(m.url).to eq 'mailto:foo@bar.com'

    m = l.match('foo@bar.com')[0]

    # assert.equal(m.text, 'foo@bar.com');
    expect(m.url).to eq 'mailto:foo@bar.com'
  end

  #------------------------------------------------------------------------------
  it 'test @twitter rule' do
    l = Linkify.new.add('@', {
      validate: lambda do |text, pos, obj|
        tail = text.slice(pos..-1)
        if (!obj.re[:twitter])
          obj.re[:twitter] =  Regexp.new(
            '^([a-zA-Z0-9_]){1,15}(?!_)(?=$|' + LinkifyRe::SRC_Z_P_CC + ')'
          )
        end
        if (obj.re[:twitter] =~ tail)
          if (pos >= 2 && text[pos - 2] == '@')
            return 0
          end
          return tail.match(obj.re[:twitter])[0].length
        end
        return 0
      end,
      normalize: lambda do |m, obj|
        m.url = 'https://twitter.com/' + m.url.sub(/^@/, '')
      end
    })

    expect(l.match('hello, @gamajoba_!')[0].text).to eq '@gamajoba_'
    expect(l.match(':@givi')[0].text).to eq '@givi'
    expect(l.match(':@givi')[0].url).to eq 'https://twitter.com/givi'
    expect(l.test('@@invalid')).to eq false
  end

  #------------------------------------------------------------------------------
  it 'set option: fuzzyLink' do
    l = Linkify.new({}, { fuzzyLink: false })

    expect(l.test('google.com.')).to eq false

    l.set({ fuzzyLink: true })

    expect(l.test('google.com.')).to eq true
    expect(l.match('google.com.')[0].text).to eq 'google.com'
  end


  #------------------------------------------------------------------------------
  it 'set option: fuzzyEmail' do
    l = Linkify.new({}, { fuzzyEmail: false })

    expect(l.test('foo@bar.com.')).to eq false

    l.set({ fuzzyEmail: true })

    expect(l.test('foo@bar.com.')).to eq true
    expect(l.match('foo@bar.com.')[0].text).to eq 'foo@bar.com'
  end

  #------------------------------------------------------------------------------
  it 'set option: fuzzyIP' do
    l = Linkify.new

    expect(l.test('1.1.1.1.')).to eq false

    l.set({ fuzzyIP: true })

    expect(l.test('1.1.1.1.')).to eq true
    expect(l.match('1.1.1.1.')[0].text).to eq '1.1.1.1'
  end

  #------------------------------------------------------------------------------
  it 'should not hang in fuzzy mode with sequences of astrals' do
    l = Linkify.new

    l.set({ fuzzyLink: true })

    expect(l.match('😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡😡 .com')).to eq []
  end

  #------------------------------------------------------------------------------
  it 'should accept `---` if enabled' do
    l = Linkify.new

    expect(l.match('http://e.com/foo---bar')[0].text).to eq 'http://e.com/foo---bar'

    l = Linkify.new(nil, { '---': true })

    expect(l.match('http://e.com/foo---bar')[0].text).to eq 'http://e.com/foo'
  end
end
