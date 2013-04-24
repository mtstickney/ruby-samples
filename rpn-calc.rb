def node(name, blocks)
  klass = Class.new do
    blocks.each do |key, val|
      define_method(key, &val)
    end
  end
  Object.const_set(name.to_s, klass)
end

def op_node(name, op_char, method = op_char)
  klass= Class.new do
    define_method(:initialize) do |left, right|
      @left = left
      @right = right
    end

    define_method(:eval) do
      return @left.eval.send(method, @right.eval)
    end

    define_method(:to_s) do
      return "#{@left.to_s} #{@right.to_s} #{op_char} "
    end
  end

  Object.const_set(name.to_s, klass)
end

node(:Num,
     :initialize => lambda{ |num| @num = num.include?('.') ? num.to_f : num.to_i },
     :eval => lambda{ return @num },
     :to_s => lambda{ return @num.to_s })

op_node(:Div, '/', 'quo')
op_node(:Add, '+')
op_node(:Sub, '-')
op_node(:Mult, '*')

def parse(toks)
  stack = Array.new
  while toks.length != 0
    tok = toks.delete_at(0)
    case tok
    when "/"
      right = stack.pop()
      left = stack.pop()
      puts "Too few arguments to division operator" unless left and right
      stack.push(Div.new(left,right))
    when "+"
      right = stack.pop()
      left = stack.pop()
      puts "Too few arguments to addition operator" unless left and right
      stack.push(Add.new(left,right))
    when "-"
      right = stack.pop()
      left = stack.pop()
      puts "Too few arguments to subtraction operator" unless left and right
      stack.push(Sub.new(left,right))
    when "*"
      right = stack.pop()
      left = stack.pop()
      puts "Too few arguments to multiplication operator" unless left and right
      stack.push(Mult.new(left,right))
    else
      stack.push(Num.new(tok))
    end
  end
  return stack.pop() if stack.length == 1
  return nil
end


ARGF.each_line do |line|
  toks = line.split
  exp = parse(toks)
  puts exp.to_s << "= " << exp.eval.to_s
end
