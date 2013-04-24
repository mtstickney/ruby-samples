class Num
  def initialize(num)
    if num.include?('.')
      @num = num.to_f
    else
      @num = num.to_i
    end
  end

  def eval()
    return @num
  end

  def to_s()
    return @num.to_s
  end
end

class Div
  def initialize(left, right)
    @left = left
    @right = right
  end

  def eval()
    return @left.eval().quo(@right.eval())
  end

  def to_s()
    return @left.to_s << " " << @right.to_s << " / "
  end
end

class Add
  def initialize(left, right)
    @left = left
    @right = right
  end

  def eval()
    return @left.eval() + @right.eval()
  end

  def to_s()
    return @left.to_s << " " << @right.to_s << " + "
  end
end

class Sub
  def initialize(left, right)
    @left = left
    @right = right
  end

  def eval()
    return @left.eval() - @right.eval()
  end

  def to_s()
    return @left.to_s << " " << @right.to_s << " - "
  end
end

class Mult
  def initialize(left, right)
    @left = left
    @right = right
  end

  def eval()
    return @left.eval() * @right.eval()
  end

  def to_s()
    return @left.to_s << " " << @right.to_s << " * "
  end
end

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
