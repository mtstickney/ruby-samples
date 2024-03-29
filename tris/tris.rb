require 'rubygems'
require 'bundler/setup'

require 'sdl'
require 'matrix'

module PieceType
  NONE = 0
  T = 1
  L = 2
  J = 3
  Z = 4
  S = 5
  O = 6
  I = 7
end

# Positions for counterclockwise rotations
module RotPosition
  NONE = 0
  FIRST = 1
  SECOND = 2
  THIRD = 3
end

BLOCK_SIZE = 40
ROWS = 22
COLS = 10

# Draw block (xindex, yindex) for a piece located at position (xpos, ypos)
def draw_block(screen, xpos, ypos, xindex, yindex, color)
  # First two rows aren't displayed
  return if ypos + yindex < 2

  # upper-right-hand corner position
  x_px = (xpos + xindex) * BLOCK_SIZE
  y_px = (ypos + yindex - 2) * BLOCK_SIZE
  w = h = BLOCK_SIZE

  # If color is false, don't draw anything
  screen.fill_rect x_px, y_px, w, h, color if color
end

class Piece
  def initialize(x, y)
    @x = x
    @y = y
    @rot = RotPosition::NONE
    @bounds_cache = Hash.new
  end

  def width()
    if @bounds_cache.has_key? [:width, @rot]
      return @bounds_cache[[:width, @rot]]
    end

    i = 0
    cols = @blocks.column_vectors
    cols.each_with_index do |vec, idx|
      if vec.inject(0) { |sum, i| sum + i } != 0
        i = idx
      end
    end

    @bounds_cache[[:width, @rot]] = i + 1
    return i + 1
  end

  def height()
    if @bounds_cache.has_key? [:height, @rot]
      return @bounds_cache[[:height, @rot]]
    end

    i = 0
    rows = @blocks.row_vectors
    rows.each_with_index do |vec, idx|
      if vec.inject(0) { |sum, i| sum + i } != 0
        i = idx
      end
    end

    @bounds_cache[[:height, @rot]] = i + 1
    return i + 1
  end

  def top
    if @bounds_cache.has_key? [:top, @rot]
      return @bounds_cache[[:top, @rot]]
    end

    rows = @blocks.row_vectors
    rows.each_with_index do |vec, idx|
      if vec.inject(0) { |sum, i| sum + i } != 0
        @bounds_cache[[:top, @rot]] = idx
        return idx
      end
    end

    @bounds_cache[[:top, @rot]] = -1
    return -1
  end

  def bottom
    return self.height - 1
  end

  def leftmost
    if @bounds_cache.has_key? [:leftmost, @rot]
      return @bounds_cache[[:leftmost, @rot]]
    end

    cols = @blocks.column_vectors
    cols.each_with_index do |vec, idx|
      if vec.inject(0) { |sum, i| sum + i } != 0
        @bounds_cache[[:leftmost, @rot]] = idx
        return idx
      end
    end

    @bounds_cache[[:leftmost, @rot]] = -1
    return -1
  end

  def rightmost
    return self.width - 1
  end

  def render(screen, as_shadow = false)
    # TODO: the color business would be cleaner with a map (or a
    # pallete)
    color = as_shadow ? HLCOLOR : FGCOLOR

    @blocks.each_with_index do |t, y, x|
      draw_block(screen, @x, @y, x, y,
                 t != PieceType::NONE ? color : false)
    end
  end

  def rotate
    bound = [self.width, self.height].max
    newblocks = Matrix.build(4) do |y, x|
      if y < bound and x < bound
        # horizontal mirror + transpose
        @blocks[x, bound - y - 1]
      else
        PieceType::NONE
      end
    end
    @blocks = newblocks
    @rot = (@rot + 1) % 4
  end

  def warp(x, y)
    @x = x
    @y = y
  end

  def print
    @blocks.row_vectors.each { |v| puts v }
  end

  attr_reader :x, :y, :blocks
end

class TPiece < Piece
  def initialize(x, y)
    super(x, y)

    t = PieceType::T
    n = PieceType::NONE
    @blocks = Matrix[[n, t, n, n],
                     [t, t, t, n],
                     [n, n, n, n],
                     [n, n, n, n]]
  end
end

class OPiece < Piece
  def initialize(x, y)
    super(x, y)
    t = PieceType::O
    n = PieceType::NONE
    @blocks = Matrix[[t, t, n, n],
                     [t, t, n, n],
                     [n, n, n, n],
                     [n, n, n, n]]
  end

  def width
    return 2
  end

  def height
    return 2
  end

  # Trivial rotate
  def rotate
  end
end

class LPiece < Piece
  def initialize(x, y)
    super(x, y)
    t = PieceType::L
    n = PieceType::NONE
    @blocks = Matrix[[n, n, t, n],
                     [t, t, t, n],
                     [n, n, n, n],
                     [n, n, n, n]]
  end
end

class JPiece < Piece
  def initialize(x, y)
    super(x, y)
    t = PieceType::J
    n = PieceType::NONE
    @blocks = Matrix[[t, n, n, n],
                     [t, t, t, n],
                     [n, n, n, n],
                     [n, n, n, n]]
  end
end

class IPiece < Piece
  def initialize(x, y)
    super(x, y)
    t = PieceType::I
    n = PieceType::NONE
    @blocks = Matrix[[n, n, n, n],
                     [t, t, t, t],
                     [n, n, n, n],
                     [n, n, n, n]]
  end
end

class ZPiece < Piece
  def initialize(x, y)
    super(x, y)
    t = PieceType::Z
    n = PieceType::NONE
    @blocks = Matrix[[t, t, n, n],
                     [n, t, t, n],
                     [n, n, n, n],
                     [n, n, n, n]]
  end
end

class SPiece < Piece
  def initialize(x, y)
    super(x, y)
    t = PieceType::S
    n = PieceType::NONE
    @blocks = Matrix[[n, t, t, n],
                     [t, t, n, n],
                     [n, n, n, n],
                     [n, n, n, n]]
  end
end

class Board
  def initialize
    @piece_class = {
      PieceType::O => OPiece,
      PieceType::I => IPiece,
      PieceType::T => TPiece,
      PieceType::J => JPiece,
      PieceType::L => LPiece,
      PieceType::Z => ZPiece,
      PieceType::S => SPiece }

    @blocks = Matrix.zero(22, 10)
    @piece = nil
    @shadow = nil
    @score = 0
    @game_over = false
  end

  def spawn_piece(type)
    case type
    when PieceType::O
      @piece = @piece_class[type].new(4, 0)
    else
      @piece = @piece_class[type].new(3, 0)
    end
    @shadow = @piece.dup
    sync_shadow
  end

  def move_piece(x, y)
    canary = @piece.clone
    canary.warp(x, y)

    leftmost = canary.leftmost
    rightmost = canary.rightmost
    top = canary.top
    bottom = canary.bottom

    if leftmost + canary.x < 0 or
        rightmost + canary.x >= COLS or
        top + canary.y < 0 or
        bottom + canary.y >= ROWS
      return false
    end

    if piece_collides(canary)
      return false
    end

    @piece.warp(x, y)
    sync_shadow
    return true
  end

  def rotate_piece
    canary = @piece.dup
    canary.rotate

    # Bump it back onto the board if necessary
    if canary.x + canary.rightmost >= COLS
      canary.warp(COLS - canary.width, @piece.y)
    elsif canary.x + canary.leftmost < 0
      canary.warp(-canary.leftmost, canary.y)
    end

    # Can't push a piece back up or extend past the bottom
    if canary.bottom + canary.y >= ROWS
      return false
    end

    if piece_collides(canary)
      return false
    end

    @piece.rotate
    @piece.warp(canary.x, canary.y)
    @shadow.rotate
    sync_shadow

    return true
  end

  def render(screen)
    @blocks.each_with_index do |t, y, x|
      draw_block(screen, 0, 0, x, y,
                 t == PieceType::NONE ? false : FGCOLOR)
    end

    @shadow.render screen, true
    @piece.render screen
  end

  def drop_piece
    @piece.warp(@piece.x, @shadow.y)
    self.set_piece
  end

  def set_piece
    @blocks = Matrix.build(ROWS, COLS) do |y, x|
      if (@piece.x...@piece.x+4).include?(x) and
          (@piece.y...@piece.y+4).include?(y) and
          @piece.blocks[y-@piece.y, x-@piece.x] != PieceType::NONE
        @piece.blocks[y-@piece.y, x-@piece.x]
      else
        @blocks[y, x]
      end
    end
  end

  def reset_timer
    @last_drop = Time.now.to_i
  end

  def falls_due
    # 1 drop per second
    Time.now.to_i - @last_drop
  end

  def clear_rows(range)
    range.each do |y|
      if @blocks.row(y).none? { |x| x == PieceType::NONE }
        @score += 1
        @blocks = Matrix.build(ROWS, COLS) do |ny, nx|
          if ny > y
            @blocks[ny, nx]
          elsif ny == 0
            # Need a fresh top row after everything has been shifted down
            PieceType::NONE
          else
            @blocks[ny-1, nx]
          end
        end
      end
    end
  end

  def end_game
    @game_over = true
  end

  def print
    @blocks.row_vectors.each { |v| puts v }
  end

  def piece_collides(piece)
    piece.blocks.each_with_index do |t, y, x|
      if y + piece.y < 0 or
          y + piece.y >= ROWS
        next
      end

      if x + piece.x < 0 or
          x + piece.x >= COLS
        next
      end

      if t != PieceType::NONE and
          @blocks[y + piece.y, x + piece.x] != PieceType::NONE
        return true
      end
    end
    return false
  end

  attr_reader :piece, :shadow, :score, :game_over

  private

  def drop_location()
    canary = @piece.clone
    i = -1
    (canary.y..ROWS-@piece.height).each do |y|
      canary.warp(canary.x, y)
      if piece_collides(canary)
        return i
      else
        i = y
      end
    end

    return i
  end

  def sync_shadow
    y = drop_location
    @shadow.warp(@piece.x, y)
  end
end

def random_piece
  (PieceType::T..PieceType::I).to_a.sample
end

def do_drop(board)
  drop_rows = Range.new(board.shadow.top+board.shadow.y,
                        board.shadow.bottom+board.shadow.y)
  if drop_rows.include? 0 or drop_rows.include? 1
    board.end_game
  end

  board.drop_piece
  board.clear_rows drop_rows
  board.spawn_piece random_piece
  board.reset_timer
end

SDL.init(SDL::INIT_VIDEO)

screen = SDL::Screen.open(BLOCK_SIZE*COLS, BLOCK_SIZE*(ROWS-2),
                          24, # bpp
                          SDL::HWSURFACE | SDL::DOUBLEBUF)

BGCOLOR = screen.format.mapRGB 0, 0, 0
FGCOLOR = screen.format.mapRGB 255, 255, 255
HLCOLOR = screen.format.mapRGB 255, 0, 0

# Event procs
cmds = {
  :drop => lambda { |board, evt| do_drop(board) },
  :rotate => lambda { |board, evt| board.rotate_piece },
  :left => lambda do |board, evt|
    board.move_piece board.piece.x - 1, board.piece.y
  end,
  :right => lambda do |board, evt|
    board.move_piece board.piece.x + 1, board.piece.y
  end,
  :print_board => lambda { |board, evt| board.print },
  :print_piece => lambda { |board, evt| board.piece.print },
  :mouse => lambda do |board, evt|
    mouse_col = evt[1] / BLOCK_SIZE
    leftmost = board.piece.leftmost
    rightmost = board.piece.rightmost
    piece_mid = (rightmost + leftmost) / 2

    step = mouse_col > piece_mid + board.piece.x ? 1 : -1
    # Move the piece until it reaches the mouse point or hits an
    # obstacle/wall
    while mouse_col != piece_mid + board.piece.x and
        board.move_piece(board.piece.x + step, board.piece.y)
    end
  end,
  :fall => lambda do |board, evt|
    # If we're already at the drop point, drop the piece
    if board.piece.x == board.shadow.x and board.piece.y == board.shadow.y
      do_drop(board)
    else
      board.move_piece board.piece.x, board.piece.y + 1
      board.reset_timer
    end
  end
  }

evts = []

board = Board.new
board.spawn_piece random_piece
board.reset_timer

shutdown = false
while not shutdown and not board.game_over
  while evt = SDL::Event2.poll
    case evt
    when SDL::Event2::Quit
      shutdown = true
    when SDL::Event2::MouseMotion
      evts.unshift [:mouse, evt.x]
    when SDL::Event2::MouseButtonDown
      case evt.button
      when SDL::Mouse::BUTTON_LEFT
        evts.unshift [:drop]
      when SDL::Mouse::BUTTON_RIGHT
        evts.unshift [:rotate]
      end
    when SDL::Event2::KeyDown
      case evt.sym
      when SDL::Key::LEFT
        evts.unshift [:left]
      when SDL::Key::RIGHT
        evts.unshift [:right]
      when SDL::Key::UP
        evts.unshift [:rotate]
      when SDL::Key::DOWN
        evts.unshift [:drop]
      when SDL::Key::B
        evts.unshift [:print_board]
      when SDL::Key::P
        evts.unshift [:print_piece]
      end
    end
  end

  # Add any timer-based moves that are due
  board.falls_due.times do
    evts.unshift [:fall]
  end

  while not evts.empty? and
      not board.game_over
    evt = evts.pop()
    cmds[evt[0]].call board, evt
  end

  # render background
  screen.fill_rect 0, 0, BLOCK_SIZE*COLS, BLOCK_SIZE*ROWS, BGCOLOR

  # render the board
  board.render screen

  screen.flip

  # Don't murder people's CPUs
  sleep(0.025)
end

puts "Final score: #{board.score}"
