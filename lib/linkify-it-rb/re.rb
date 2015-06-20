module LinkifyRe
    
    # Use direct extract instead of `regenerate` to reduce size
    SRC_ANY = UCMicro::Properties::Any::REGEX.source
    SRC_CC  = UCMicro::Categories::Cc::REGEX.source
    SRC_Z   = UCMicro::Categories::Z::REGEX.source
    SRC_P   = UCMicro::Categories::P::REGEX.source

    # \p{\Z\P\Cc} (white spaces + control + punctuation)
    SRC_Z_P_CC = [ SRC_Z, SRC_P, SRC_CC ].join('|')

    # \p{\Z\Cc} (white spaces + control)
    SRC_Z_CC = [ SRC_Z, SRC_CC ].join('|')

    # All possible word characters (everything without punctuation, spaces & controls)
    # Defined via punctuation & spaces to save space
    # Should be something like \p{\L\N\S\M} (\w but without `_`)
    SRC_PSEUDO_LETTER       = '(?:(?!' + SRC_Z_P_CC + ')' + SRC_ANY + ')'
    # The same as above but without [0-9]
    SRC_PSEUDO_LETTER_NON_D = '(?:(?![0-9]|' + SRC_Z_P_CC + ')' + SRC_ANY + ')'

    #------------------------------------------------------------------------------

    SRC_IP4   = '(?:(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)'
    SRC_AUTH  = '(?:(?:(?!' + SRC_Z_CC + ').)+@)?'

    SRC_PORT  = '(?::(?:6(?:[0-4]\\d{3}|5(?:[0-4]\\d{2}|5(?:[0-2]\\d|3[0-5])))|[1-5]?\\d{1,4}))?'

    SRC_HOST_TERMINATOR = '(?=$|' + SRC_Z_P_CC + ')(?!-|_|:\\d|\\.-|\\.(?!$|' + SRC_Z_P_CC + '))'

    SRC_PATH = 
      '(?:' +
        '[/?#]' +
          '(?:' +
            '(?!' + SRC_Z_CC + '|[()\\[\\]{}.,"\'?!\\-]).|' +
            '\\[(?:(?!' + SRC_Z_CC + '|\\]).)*\\]|' +
            '\\((?:(?!' + SRC_Z_CC + '|[)]).)*\\)|' +
            '\\{(?:(?!' + SRC_Z_CC + '|[}]).)*\\}|' +
            '\\"(?:(?!' + SRC_Z_CC + '|["]).)+\\"|' +
            "\\'(?:(?!" + SRC_Z_CC + "|[']).)+\\'|" +
            "\\'(?=" + SRC_PSEUDO_LETTER + ').|' +  # allow `I'm_king` if no pair found
            '\\.{2,3}[a-zA-Z0-9%/]|' + # github has ... in commit range links. Restrict to
                                       # - english
                                       # - percent-encoded
                                       # - parts of file path
                                       # until more examples found.
            '\\.(?!' + SRC_Z_CC + '|[.]).|' +
            '\\-(?!' + SRC_Z_CC + '|--(?:[^-]|$))(?:[-]+|.)|' +  # `---` => long dash, terminate
            '\\,(?!' + SRC_Z_CC + ').|' +      # allow `,,,` in paths
            '\\!(?!' + SRC_Z_CC + '|[!]).|' +
            '\\?(?!' + SRC_Z_CC + '|[?]).' +
          ')+' +
        '|\\/' +
      ')?'

    SRC_EMAIL_NAME  = '[\\-;:&=\\+\\$,\\"\\.a-zA-Z0-9_]+'
    SRC_XN          = 'xn--[a-z0-9\\-]{1,59}'

    # More to read about domain names
    # http://serverfault.com/questions/638260/

    SRC_DOMAIN_ROOT = 
      # Can't have digits and dashes
      '(?:' +
        SRC_XN +
        '|' +
        SRC_PSEUDO_LETTER_NON_D + '{1,63}' +
      ')'

    SRC_DOMAIN = 
      '(?:' +
        SRC_XN +
        '|' +
        '(?:' + SRC_PSEUDO_LETTER + ')' +
        '|' +
        # don't allow `--` in domain names, because:
        # - that can conflict with markdown &mdash; / &ndash;
        # - nobody use those anyway
        '(?:' + SRC_PSEUDO_LETTER + '(?:-(?!-)|' + SRC_PSEUDO_LETTER + '){0,61}' + SRC_PSEUDO_LETTER + ')' +
      ')'

    SRC_HOST = 
      '(?:' +
        SRC_IP4 +
      '|' +
        '(?:(?:(?:' + SRC_DOMAIN + ')\\.)*' + SRC_DOMAIN_ROOT + ')' +
      ')'

    TPL_HOST_FUZZY = 
      '(?:' +
        SRC_IP4 +
      '|' +
        '(?:(?:(?:' + SRC_DOMAIN + ')\\.)+(?:%TLDS%))' +
      ')'

    TPL_HOST_NO_IP_FUZZY =
      '(?:(?:(?:' + SRC_DOMAIN + ')\\.)+(?:%TLDS%))'

    SRC_HOST_STRICT            = SRC_HOST + SRC_HOST_TERMINATOR
    TPL_HOST_FUZZY_STRICT      = TPL_HOST_FUZZY + SRC_HOST_TERMINATOR
    SRC_HOST_PORT_STRICT       = SRC_HOST + SRC_PORT + SRC_HOST_TERMINATOR
    TPL_HOST_PORT_FUZZY_STRICT = TPL_HOST_FUZZY + SRC_PORT + SRC_HOST_TERMINATOR
    TPL_HOST_PORT_NO_IP_FUZZY_STRICT = TPL_HOST_NO_IP_FUZZY + SRC_PORT + SRC_HOST_TERMINATOR
      
    #------------------------------------------------------------------------------
    # Main rules

    # Rude test fuzzy links by host, for quick deny
    TPL_HOST_FUZZY_TEST = 'localhost|\\.\\d{1,3}\\.|(?:\\.(?:%TLDS%)(?:' + SRC_Z_P_CC + '|$))'
    TPL_EMAIL_FUZZY     = '(^|>|' + SRC_Z_CC + ')(' + SRC_EMAIL_NAME + '@' + TPL_HOST_FUZZY_STRICT + ')'
    TPL_LINK_FUZZY =
        # Fuzzy link can't be prepended with .:/\- and non punctuation.
        # but can start with > (markdown blockquote)
        '(^|(?![.:/\\-_@])(?:[$+<=>^`|]|' + SRC_Z_P_CC + '))' +
        '((?![$+<=>^`|])' + TPL_HOST_PORT_FUZZY_STRICT + SRC_PATH + ')'

    TPL_LINK_NO_IP_FUZZY =
        # Fuzzy link can't be prepended with .:/\- and non punctuation.
        # but can start with > (markdown blockquote)
        '(^|(?![.:/\\-_@])(?:[$+<=>^`|]|' + SRC_Z_P_CC + '))' +
        '((?![$+<=>^`|])' + TPL_HOST_PORT_NO_IP_FUZZY_STRICT + SRC_PATH + ')'
end