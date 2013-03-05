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

  # Get the value of a register
  #
  # @param [Symbol] reg the register, one of :R0 through :R7,
  #   :PC, :IR, :PSR, or :CC
  # @return [String] the register value in hex format (e.g., 'x0000') or nil
  #   if the register does not exist.
  def get_register(reg)
    reg = reg.to_s.upcase.to_sym  # Ruby 1.8 doesn't support Symbol#upcase
    @registers[reg]
  end

  # Set the value of a register
  #
  # @param (see #get_register)
  # @param [String] val the register value in hex format (e.g., 'xF1D0')
  # @raise [ArgumentError] if the register is invalid or the value is nil,
  # @return [self]
  def set_register(reg, val)
    reg = reg.upcase

    unless @registers.keys.include? reg.to_sym
      raise ArgumentError, "Invalid register: #{reg.to_s}"
    end

    if val.nil?
      raise ArgumentError, "Invalid register value for #{reg.to_s}: #{val}"
    end

    if reg.to_sym == :CC and not ['POSITIVE', 'NEGATIVE', 'ZERO'].include? val
      raise ArgumentError, "CC can only be set to NEGATIVE, ZERO, or POSITIVE"
    end

    @io.puts "register #{reg.to_s} #{normalize_to_s(val)}"

    loop do
      msg = @io.readline
      parse_msg msg.strip

      break if msg =~ /^ERR|TOCODE/
    end

    self
  end

  # Return value in memory at the given address or label
  #
  # @param [String] addr an address in hex format (e.g., 'xADD4') or a label
  # @raise [ArgumentError] if the argument is not a existing label or is an
  #   invalid address
  # @return [String] the value in memory in hex format
  def get_memory(addr)
    if addr.respond_to?(:upcase)
      label_addr = get_address(addr.upcase)

      return @memory[label_addr] unless label_addr.nil?
    end

    @memory[normalize_to_s(addr)]
  end

  # Set memory at the given address or label
  #
  # If val is a label, mem[addr] will be set to the address of val
  #
  # @param [String] addr an address or a label
  # @param [String] val a value or a label
  # @raise [ArgumentError] if addr is not an existing label, addr is an
  #   invalid address, val is not an existing label, or val is invalid
  # @return [self]
  def set_memory(addr, val)
    # addr may be memory address or label

    if addr.respond_to?(:upcase) and @labels.include?(addr.upcase.to_s)
      # Is a label
      addr = addr.upcase.to_s
    else
      # Not a label
      addr = normalize_to_s(addr)
    end

    # Value can be a label too
    if val.respond_to?(:upcase) and @labels.include?(val.upcase.to_s)
      # Is a label
    else
      # Is a value
      val = normalize_to_s(val)
    end

    @io.puts("memory #{addr} #{val}")

    loop do
      msg = @io.readline
      parse_msg msg.strip

      break if msg =~ /^ERR|CODE/
    end

    self
  end

  # Get the address of a label
  #
  # @param [String] label
  # @return [String] the address of the label, or nil if the label does
  #   not exist
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

  # Execute one instruction
  #
  # @return [self]
  def step
    @io.puts 'step'

    parse_until_print_registers

    self
  end

  # Execute instructions until halt or breakpoint
  #
  # @return [self]
  def continue
    @io.puts 'continue'

    parse_until_print_registers

    self
  end

  # Set a breakpoint at an address or label
  #
  # @param (see #get_memory)
  # @raise (see #get_memory)
  # @return [self]
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

  # Clear a breakpoint at an address or label
  #
  # @param (see #set_breakpoint)
  # @raise (see #set_breakpoint)
  # @return [self]
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

  # Clear all breakpoints
  #
  # @return [self]
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

  def close
    @output.close
    @server.close
  end

  def inspect
    registers = @registers.map { |k, v| "#{k}=#{v}" }.join(' ')

    addr_to_label = @labels.invert

    memory_header = "%18s ADDR  VALUE" % "label"
    memory = @memory.map do |addr, value|
      "%18s %s %s" % [(addr_to_label[addr] or ''), addr, value]
    end.join("\n")

    #[memory_header, memory, registers].join("\n")
    registers
  end

  # def to_s
  #   @registers.map { |k, v| "#{k}=#{v}" }.join(' ')
  # end

  private

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
      # Numeric address
      num_addr = tokens.shift.to_i - 1

      # Note: if there is a breakpoint at the current address, the last
      # token.shift produces a string like "12289B". Luckily, to_i just
      # reads whatever it can and discards the rest.

      # Label, if present
      label = tokens.first != "x%04X" % num_addr ? tokens.shift.upcase : nil

      # hex address
      addr = tokens.shift

      # Insert label, but don't overwrite if it already exists
      @labels[label] ||= addr if not label.nil?

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
