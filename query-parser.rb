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

    return self.streamToken
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

def unshift_toks(lexer, tokens)
  tokens.reverse_each { |t| lexer.pushToken(t) }
  return false
end

# Read a sequence of tokens or reset the lexer
def token_seq(lexer, tokens)
  read_tokens = []
  tokens.each do |tok|
    if tok.instance_of?(Symbol)
      read_tokens << lexer.nextToken
      return unshift_toks(lexer, read_tokens) unless read_tokens.last[0] == tok
    elsif tok.instance_of?(Class)
      toks = tok.new(lexer).parse
      return unshift_toks(lexer, read_tokens) unless toks

      read_tokens = read_tokens + toks
    else
      raise TypeError, "Token designator #{tok} is not a Symbol or Class"
    end
  end

  return read_tokens
end

def token_choice(lexer, tokens)
  tokens.each do |toks|
    ts = token_seq(lexer, toks)
    return ts if ts
  end

  return false
end

def optional_seq(tok_seq)
  klass = Class.new do
    define_method(:initialize) { |lexer| @lexer = lexer }
    define_method(:parse) do
      return token_choice(@lexer, [tok_seq, []])
    end
  end

  return klass
end

class WordSeq
  def initialize(lexer)
    @lexer = lexer
  end

  def parse()
    puts "Parsing WordSeq"
    tokens = token_seq(@lexer, [:word])
    return false unless tokens

    while toks = token_seq(@lexer, [:whitespace, :word])
      tokens = tokens + toks[1] if toks
    end

    return tokens
  end
end

class Pw
  def initialize(lexer)
    @lexer = lexer
  end

  def parse()
    puts "Parsing Pw"
    tokens = token_choice(@lexer, [[:phrase],
                                   [WordSeq]])
    return tokens
  end
end

class Exclusion
  def initialize(lexer)
    @lexer = lexer
  end

  def parse()
    puts "Parsing Exclusion"
    tokens = token_choice(@lexer, [[:exclude_op, :word],
                                   [:exclude_op, :phrase]])

    return tokens
  end
end

class Inclusion
  def initialize(lexer)
    @lexer = lexer
  end

  def parse()
    puts "Parsing Inclusion"
    tokens = token_choice(@lexer, [[:include_op, :word],
                                   [:include_op, :phrase]])

    return tokens
  end
end

class PrefixTerm
  def initialize(lexer)
    @lexer = lexer
  end

  def parse()
    puts "Parsing PrefixTerm"
    tokens = token_seq(@lexer, [:word, :star_op])

    return tokens
  end
end

class Term
  def initialize(lexer)
    @lexer = lexer
  end

  def parse()
    puts "Parsing Term"
    tokens = token_choice(@lexer,
                          [[Exclusion],
                           [Inclusion],
                           [PrefixTerm],
                           [Pw],
                           # Parenthesized expression w/ optional whitespace
                           [:lparen,
                            optional_seq([:whitespace]),
                            Query,
                            optional_seq([:whitespace]),
                            :rparen]])
    return tokens
  end
end

class AndTerm
  def initialize(lexer)
    @lexer = lexer
  end

  def parse()
    puts "Parsing AndTerm"
    tokens = token_seq(@lexer, [Term])
    return false unless tokens

    while next_toks = token_seq(@lexer, [:whitespace, :and, :whitespace, AndTerm])
      tokens = tokens + next_toks if next_toks
    end
    return tokens
  end
end

class OrTerm
  def initialize(lexer)
    @lexer = lexer
  end

  def parse()
    puts "Parsing OrTerm"
    tokens = token_seq(@lexer, [AndTerm])

    while next_toks = token_seq(@lexer, [:whitespace, :or, :whitespace, AndTerm])
      tokens = tokens + next_toks if next_toks
    end
    return tokens
  end
end

class Query
  def initialize(lexer)
    @lexer = lexer
  end

  def parse()
    puts "Parsing Query"
    return token_seq(@lexer, [optional_seq([:whitespace]),
                              OrTerm,
                              optional_seq([:whitespace])])
  end
end

ARGF.each_line do |line|
  puts "Query: " << line
  puts "Full token stream:"
  lex = Lexer.new(line)
  begin
    tok = lex.nextToken
    puts "[" << (tok[0].to_s) << ", '" << tok[1] << "']"
  end until tok[0] == :unknown or tok[0] == :eof
  lex = Lexer.new(line)
  print "Parser/recognizer:"
  tokens = Query.new(lex).parse
  next_tok = lex.nextToken
  if not tokens
    print false
    puts ": Recognizer failed"
  elsif next_tok[0] != :eof
    print false
    puts ": Unexpected tokens at end of input (#{next_tok})"
  else
    puts true
  end
end
