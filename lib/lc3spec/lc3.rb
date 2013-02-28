# lc3.rb
# Chun Yang <yang43@illinois.edu>

require 'io/wait'
require 'logger'
require 'socket'
require 'tempfile'

require 'lc3spec/errors'
require 'lc3spec/helpers'

# Class to provide access to LC-3 simulator instance
class LC3
  include LC3Spec::Helpers
  attr_accessor :logger

  def initialize
    # Logging
    @logger = Logger.new(STDERR)
    if ENV['LC3DEBUG']
      @logger.level = Logger::DEBUG
    else
      @logger.level = Logger::ERROR
    end
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "#{severity}: #{msg}\n"
    end

    # Registers
    @registers = {}
    [:R0, :R1, :R2, :R3, :R4, :R5, :R6, :R7, :PC, :IR, :PSR].each do |reg|
      @registers[reg] = 'x0000'
    end
    @registers[:CC] = 'ZERO'

    # Memory
    @memory = Hash.new('x0000')
    @labels = {}

    initialize_lc3sim
  end

  def get_register(reg)
    reg = reg.to_s.upcase.to_sym  # Ruby 1.8 doesn't support Symbol#upcase
    @registers[reg]
  end

  def set_register(reg, val)
    reg = reg.to_s.upcase # Don't use ! version because it doesn't work for symbols

    unless @registers.keys.include? reg.to_sym
      raise "Invalid register: #{reg.to_s}"
    end

    if val.nil?
      raise "Invalid register value for #{reg.to_s}: #{val}"
    end

    @io.puts "register #{reg.to_s} #{normalize_to_s(val)}"

    loop do
      msg = @io.readline
      parse_msg msg.strip

      break if msg =~ /^TOCODE/
    end

    self
  end

  def get_memory(addr)
    if addr.respond_to?(:upcase)
      label_addr = get_address(addr)
      addr = label_addr unless label_addr.nil?
    end

    @memory[normalize_to_i(addr)]
  end

  def set_memory(addr, val)
    # addr may be memory address or label

    if addr.respond_to?(:upcase) and @labels.include?(addr.upcase.to_s)
      # Is a label
      addr = addr.upcase.to_s
    else
      # Not a label
      addr = normalize_to_s(addr)
    end

    @io.puts("memory #{addr} #{normalize_to_s(val)}")

    loop do
      msg = @io.readline
      parse_msg msg.strip

      break if msg =~ /^ERR|CODE/
    end

    self
  end

  def get_address(label)
    @labels[label.upcase.to_s]
  end

  def file(filename)
    @io.puts "file #{filename}"

    # Need to encounter 2 TOCODEs before we're done
    tocode_counter = 2

    while tocode_counter > 0
      msg = @io.readline

      parse_msg msg.strip

      if msg =~ /^TOCODE/
        tocode_counter -= 1
      end

      # ignore warning about no symbols
      next if msg =~ /WARNING: No symbols/

      # don't ignore other errors
      break if msg =~ /^ERR/
    end

    self
  end

  def step
    @io.puts 'step'

    parse_until_print_registers

    self
  end

  def continue
    @io.puts 'continue'

    parse_until_print_registers

    self
  end

  def set_breakpoint(addr)
    addr = addr.upcase.to_s if addr.respond_to? :upcase
    if @labels.include? addr
      @io.puts "break set #{addr}"
    else
      @io.puts "break set #{normalize_to_s(addr)}"
    end

    sleep(0.01)

    while @io.ready?
      msg = @io.readline
      parse_msg msg.strip
    end

    self
  end

  def clear_breakpoint(addr)
    if addr == :all
      @io.puts 'break clear all'
      return self
    end

    addr = addr.upcase.to_s if addr.respond_to? :upcase

    if @labels.include? addr
      @io.puts "break clear #{addr}"
    else
      @io.puts "break clear #{normalize_to_s(addr)}"
    end

    sleep(0.01)

    while @io.ready?
      msg = @io.readline
      parse_msg msg.strip
    end

    self
  end

  def clear_breakpoints
    clear_breakpoint :all
  end

  def get_output
    out = ''

    # There is no signal that tells the GUI that output is ready...
    # FIXME: This is a bug waiting to happen
    retries = 10
    until @output.ready?
      sleep(0.1)

      retries -= 1
      break if retries <= 0
    end

    while @output.ready?
      out << @output.readpartial(1024)
    end

    out.gsub("\n\n--- halting the LC-3 ---\n\n", '')
  end

  def initialize_lc3sim
    # Start lc3sim instance
    @io = IO.popen(%w(lc3sim -gui), 'r+')

    begin
      # Port for output server
      @port = (rand * 1000 + 5000).to_i

      # Start server to get output
      @server = TCPServer.new @port
    rescue Errno::EADDRINUSE
      retry
    end

    th = Thread.new do
      @output = @server.accept
    end

    # Initialize lc3sim with port number
    @io.puts @port

    # Wait for lc3sim to connect with our server
    th.join

    # Read LC-3 initialization messages (mostly loading lc3os)
    parse_until_print_registers

    # Clear all the welcome messages from lc3sim output
    while @output.ready?
      @output.readpartial 1024
    end
  end

  def close
    @output.close
    @server.close
  end

  def inspect
    registers = @registers.map { |k, v| "#{k}=#{v}" }.join(' ')

    addr_to_label = @labels.invert

    memory_header = "%18s ADDR  VALUE" % "label"
    memory = @memory.map do |addr, value|
      "%18s %s %s" % [(addr_to_label[addr] or ''),
                      normalize_to_s(addr), value]
    end.join("\n")

    #[memory_header, memory, registers].join("\n")
    registers
  end

  # def to_s
  #   @registers.map { |k, v| "#{k}=#{v}" }.join(' ')
  # end

  private

  def parse_until_print_registers
    loop do
      msg = @io.readline
      parse_msg msg.strip

      break if msg =~ /^REG R11/
    end
  end

  # Parse messages from lc3sim
  def parse_msg(msg)
    @logger.debug msg

    tokens = msg.split(/ +/)

    cmd = tokens.shift

    if cmd =~ /^CODEP/
      tokens.unshift(cmd.gsub('CODEP', ''))
      cmd = 'CODEP'
    end

    case cmd
    when 'BCLEAR'
    when 'BREAK'
    when 'CODE', 'CODEP'  # Line of code
      # Address
      addr = tokens.shift.to_i - 1

      # Note: if there is a breakpoint at the current address, the last
      # token.shift produces a string like "12289B". Luckily, #to_i just
      # ignores the B at the end.

      # Label, if present
      if tokens.first != "x%04X" % addr
        label = tokens.shift.upcase

        # Don't overwrite label if one already exists
        @labels[label] ||= addr
      end

      # Discard hex address
      tokens.shift

      # Value
      val = tokens.shift

      @memory[addr] = val

      # Disassembly info
      # info = tokens.join(' ')

    when 'CONT'
    when 'ERR'
      if msg =~ /WARNING/
        @logger.warn msg
      else
        @logger.error msg
      end
    when 'REG'            # Register value
      # Register number
      reg = tokens.shift

      # Register value
      val = tokens.shift

      case reg
      when /^R[0-7]$/
        @registers[reg.to_sym] = val
      when 'R8'
        @registers[:PC] = val
      when 'R9'
        @registers[:IR] = val
      when 'R10'
        @registers[:PSR] = val
      when 'R11'
        @registers[:CC] = val
      end
    when 'TOCODE'
    when 'TRANS'          # Label address translation
      addr = normalize_to_i(tokens.shift)
      val = tokens.shift
    else
      @logger.debug "Unexpected message: #{msg}"
    end
  end

end
