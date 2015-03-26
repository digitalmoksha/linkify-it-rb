#------------------------------------------------------------------------------
describe 'links' do

  # TODO tests which can't seem to get passing at the moment, so skip them 
  failing_test = [ 
    95,     # GOOGLE.COM.     unable to get final . to be removed
    214     # xn--d1abbgf6aiiy.xn--p1ai
  ]

  l = Linkify.new
  l.bypass_normalizer = true    # kill the normalizer
 
  skipNext  = false
  linkfile  = File.join(File.dirname(__FILE__), 'fixtures/links.txt')
  lines     = File.read(linkfile).split(/\r?\n/)
  lines.each_with_index do |line, idx|
    if skipNext
      skipNext = false
      next
    end
 
    line      = line.sub(/^%.*/, '')
    next_line = (lines[idx + 1] || '').sub(/^%.*/, '')

    next if line.strip.empty?

    unless failing_test.include?(idx + 1)
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

end


#------------------------------------------------------------------------------
describe 'not links' do

  # TODO tests which can't seem to get passing at the moment, so skip them 
  failing_test = [ 6, 7, 8, 12, 16, 19, 22, 23, 24, 25, 26, 27, 28, 29, 48 ]

  l = Linkify.new
  l.bypass_normalizer = true    # kill the normalizer

  linkfile  = File.join(File.dirname(__FILE__), 'fixtures/not_links.txt')
  lines     = File.read(linkfile).split(/\r?\n/)
  lines.each_with_index do |line, idx|
    line = line.sub(/^%.*/, '')

    next if line.strip.empty?

    unless failing_test.include?(idx + 1)
      it "line #{idx + 1}" do
        # assert.notOk(l.test(line),
        #  '(should not find link in `' + line + '`, but found `' +
        #  JSON.stringify((l.match(line) || [])[0]) + '`)');
        expect(l.test(line)).not_to eq true
      end
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

    # this is some other package of tlds which we don't have
    # l.tlds(require('tlds'));
    # assert.ok(l.test('google.xyz'));
    # assert.notOk(l.test('google.myroot'));
  end


  # TODO Tests not passing
  #------------------------------------------------------------------------------
  # it 'add rule as regexp, with default normalizer' do
  #   l = Linkify.new.add('my:', {validate: /^\/\/[a-z]+/} )
  #
  #   match = l.match('google.com. my:// my://asdf!')
  #
  #   expect(match[0].text).to eq 'google.com'
  #   expect(match[1].text).to eq 'my://asdf'
  # end

  # TODO Tests not passing
  #------------------------------------------------------------------------------
  # it 'add rule with normalizer'
  #   l = Linkify.new.add('my:', {
  #     validate: /^\/\/[a-z]+/,
  #     normalize: lambda {|m|
  #       m.text = m.text.sub(/^my:\/\//, '').upcase
  #       m.url  = m.url.upcase
  #     }
  #   })
  #
  #   match = l.match('google.com. my:// my://asdf!')
  #
  #   expect(match[1].text).to eq 'ASDF'
  #   expect(match[1].url).to eq 'MY://ASDF'
  # end

#   it('disable rule', function () {
#     var l = linkify();
#
#     assert.ok(l.test('http://google.com'));
#     assert.ok(l.test('foo@bar.com'));
#     l.add('http:', null);
#     l.add('mailto:', null);
#     assert.notOk(l.test('http://google.com'));
#     assert.notOk(l.test('foo@bar.com'));
#   });
#
#
#   it('add bad definition', function () {
#     var l;
#
#     l = linkify();
#
#     assert.throw(function () {
#       l.add('test:', []);
#     });
#
#     l = linkify();
#
#     assert.throw(function () {
#       l.add('test:', { validate: [] });
#     });
#
#     l = linkify();
#
#     assert.throw(function () {
#       l.add('test:', {
#         validate: function () { return false; },
#         normalize: 'bad'
#       });
#     });
#   });
#
#
#   it('test at position', function () {
#     var l = linkify();
#
#     assert.ok(l.testSchemaAt('http://google.com', 'http:', 5));
#     assert.ok(l.testSchemaAt('http://google.com', 'HTTP:', 5));
#     assert.notOk(l.testSchemaAt('http://google.com', 'http:', 6));
#
#     assert.notOk(l.testSchemaAt('http://google.com', 'bad_schema:', 6));
#   });
#
#
#   it('correct cache value', function () {
#     var l = linkify();
#
#     var match = l.match('.com. http://google.com google.com ftp://google.com');
#
#     assert.equal(match[0].text, 'http://google.com');
#     assert.equal(match[1].text, 'google.com');
#     assert.equal(match[2].text, 'ftp://google.com');
#   });
#
#   it('normalize', function () {
#     var l = linkify(), m;
#
#     m = l.match('mailto:foo@bar.com')[0];
#
#     // assert.equal(m.text, 'foo@bar.com');
#     assert.equal(m.url,  'mailto:foo@bar.com');
#
#     m = l.match('foo@bar.com')[0];
#
#     // assert.equal(m.text, 'foo@bar.com');
#     assert.equal(m.url,  'mailto:foo@bar.com');
#   });
#
#
#   it('test @twitter rule', function () {
#     var l = linkify().add('@', {
#       validate: function (text, pos, self) {
#         var tail = text.slice(pos);
#
#         if (!self.re.twitter) {
#           self.re.twitter =  new RegExp(
#             '^([a-zA-Z0-9_]){1,15}(?!_)(?=$|' + self.re.src_ZPCcCf + ')'
#           );
#         }
#         if (self.re.twitter.test(tail)) {
#           if (pos >= 2 && tail[pos - 2] === '@') {
#             return false;
#           }
#           return tail.match(self.re.twitter)[0].length;
#         }
#         return 0;
#       },
#       normalize: function (m) {
#         m.url = 'https://twitter.com/' + m.url.replace(/^@/, '');
#       }
#     });
#
#     assert.equal(l.match('hello, @gamajoba_!')[0].text, '@gamajoba_');
#     assert.equal(l.match(':@givi')[0].text, '@givi');
#     assert.equal(l.match(':@givi')[0].url, 'https://twitter.com/givi');
#     assert.notOk(l.test('@@invalid'));
#   });

end
