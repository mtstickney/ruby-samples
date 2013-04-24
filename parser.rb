class Lexer
  def initialize(stream)
    @tokens = []
    @stream = stream
    # Not a map because we need to preserve ordering
    @matchtable = [[/^\+/, :include_op],
                   [/^-/, :exclude_op],
                   [/^\(/, :lparen],
                   [/^\)/, :rparen],
                   [/^"[^"]+"/, :phrase],
                   [/^\*/, :star_op],
                   [/^\s+/, :whitespace],
                   # If AND/OR isn't followed by whitespace, it's just
                   # a word
                   [/^AND(?=\s)/, :and],
                   [/^OR(?=\s)/, :or],
                   [/^[[:alnum:]@%\$&][[:alnum:]@%\$&]*/, :word],
                   [/^\z/, :eof]]
  end

  def nextToken()
    if @tokens.size != 0
      return @tokens.pop()
    end

    token = self.streamToken
    return token
  end

  def streamToken()
    token = nil
    @matchtable.each do |entry|
      if entry[0] =~ @stream
        token = [entry[1], Regexp.last_match[0]]
        @stream = @stream[token[1].length..-1]
        return token
      end
    end

    return [:unknown, '']
  end

  def pushToken(tok)
    @tokens.push(tok)
  end
end

class WordSeq
  def initialize(lexer)
    @lexer = lexer
  end

  def parse()
    puts "Parsing WordSeq"
    tokens = []
    token = @lexer.nextToken
    tokens << token
    if token[0] != :word
      @lexer.pushToken(token)
      return false
    end
    
    begin
      token = @lexer.nextToken
      tokens << token
    end until token[0] != :word
    @lexer.pushToken(token)
    tokens.pop
    return tokens
  end
end

class Pw
  def initialize(lexer)
    @lexer = lexer
  end

  def parse()
    puts "Parsing Pw"
    tokens = []
    token = @lexer.nextToken
    tokens << token
    if token[0] == :phrase
      return tokens
    end

    @lexer.pushToken(token)
    tokens.pop
    word_tokens = WordSeq.new(@lexer).parse
    if not word_tokens
      return false
    end
    return word_tokens
  end
end

class Exclusion
  def initialize(lexer)
    @lexer = lexer
  end

  def parse()
    puts "Parsing Exclusion"
    tokens = []
    token = @lexer.nextToken
    tokens << token
    if token[0] != :exclusion
      @lexer.pushToken(token)
      return false
    end
    return tokens
  end
end

class Inclusion
  def initialize(lexer)
    @lexer = lexer
  end

  def parse()
    puts "Parsing Inclusion"
    tokens = []
    token = @lexer.nextToken
    tokens << token
    if token[0] != :inclusion
      @lexer.pushToken(token)
      return false
    end
    return tokens
  end
end

class PrefixTerm
  def initialize(lexer)
    @lexer = lexer
  end

  def parse()
    puts "Parsing PrefixTerm"
    tokens = []
    token = @lexer.nextToken
    tokens << token
    if token[0] != :prefixterm
      @lexer.pushToken(token)
      return false
    end
    return tokens
  end
end

class Term
  def initialize(lexer)
    @lexer = lexer
  end

  def parse()
    puts "Parsing Term"
    toks = Pw.new(@lexer).parse
    return toks if toks
    toks = Exclusion.new(@lexer).parse
    return toks if toks
    toks = Inclusion.new(@lexer).parse
    return toks if toks
    toks = PrefixTerm.new(@lexer).parse
    return toks if toks

    tokens = []
    token = @lexer.nextToken
    tokens << token
    if token[0] != :lparen
      @lexer.pushToken(token)
      return false
    end
    # Note that we use Orterm here instead of Query,
    # since Query is not defined in our grammar.
    toks = OrTerm.new(@lexer).parse
    if not toks
      @lexer.pushToken(token)
      return false
    end
    toks.each { |tok| tokens << tok }
    token2 = @lexer.nextToken
    tokens << token2
    if token2[0] != :rparen
      tokens.reverse_each { |tok| @lexer.pushToken(tok) }
      return false
    end
    return tokens
  end
end

class AndTerm
  def initialize(lexer)
    @lexer = lexer
  end

  def parse()
    puts "Parsing AndTerm"
    toks = Term.new(@lexer).parse
    if not toks
      return false
    end

    new_toks = []
    begin
      and_token = @lexer.nextToken
      toks << and_token
      if and_token[0] == :AND
        new_toks = Term.new(@lexer).parse
        new_toks.each { |tok| toks << tok }
      end
    end until and_token[0] != :AND or not new_toks

    if and_token[0] != :AND
      @lexer.pushToken(and_token)
      toks.pop
      return toks
    end

    if not new_toks
      @lexer.pushToken(and_token)
      toks.reverse_each { |tok| @lexer.pushToken(tok) }
      return false
    end
    return toks
  end
end

class OrTerm
  def initialize(lexer)
    @lexer = lexer
  end

  def parse()
    puts "Parsing OrTerm"
    toks = AndTerm.new(@lexer).parse
    if not toks
      return false
    end

    new_toks = []
    begin
      or_token = @lexer.nextToken
      toks << or_token
      if or_token[0] == :OR
        new_toks = AndTerm.new(@lexer).parse
        new_toks.each { |tok| toks << tok }
      end
    end until or_token[0] != :OR or not new_toks

    if or_token[0] != :OR
      @lexer.pushToken(or_token)
      toks.pop
      return toks
    end

    if not new_toks
      @lexer.pushToken(or_token)
      toks.reverse_each { |tok| @lexer.pushToken(tok) }
      return false
    end
    return toks
  end
end
    
ARGF.each_line do |line|
  puts "Query: " << line
  puts "Full token stream:"
  lex = Lexer.new(line)
  begin
    tok = lex.nextToken
    puts "[" << (tok[0].to_s) << ", '" << tok[1] << "']"
  end until tok[0] == :unknown or tok[0] == :eos
  
  lex = Lexer.new(line)
  print "Parser/recognizer:"
  tokens = OrTerm.new(lex).parse
  if not tokens
    print false
    puts ": Recognizer failed"
  elsif lex.nextToken[0] != :eos
    print false
    puts ": Unexpected tokens at end of input"
  else
    puts true
  end
end
