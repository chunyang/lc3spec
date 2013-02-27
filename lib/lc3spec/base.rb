require 'open3'

require 'lc3spec/constants'
require 'lc3spec/lc3'
require 'lc3spec/helpers'
require 'lc3spec/errors'

module LC3Spec
  class Test
    include LC3Spec::Helpers

    def initialize(description, options, &block)
      # Save src_dir
      @src_dir = File.expand_path(Dir.pwd)

      # Do everything inside tmp_dir
      Dir.mktmpdir('spec') do |tmp_dir|
        Dir.chdir(tmp_dir) do
          @lc3 = LC3.new

          instance_eval(&block) if block_given?
        end
      end
    end

    def set_register(reg, val = 0)
      case reg
      when Hash
        reg.each do |r, v|
          @lc3.set_register(r, v)
        end
      when Array
        reg.each_with_index do |v, i|
          @lc3.set_register("R#{i}", v)
        end
      else
        @lc3.set_register(reg, val)
      end
    end

    alias_method :set_registers, :set_register

    def file_from_asm(asm)
      assemble_and_load { |f| f.puts asm }

      self
    end

    def file(filename)
      ensure_present(filename)
      ensure_assembled(filename)
      @lc3.file(filename)

      self
    end

    alias_method :load_file, :file

    def set_label(label, addr)
      label = label.to_s.upcase

      if @labels.include? label
        raise "Unable to replace label #{label}"
      end

      assemble_and_load do |f|
        f.puts ".ORIG #{normalize_to_s(addr)}\n#{label}\n.END"
      end

      self
    end

    def method_missing(method_name, *arguments, &block)
      if @lc3.respond_to? method_name
        @lc3.send(method_name, *arguments, &block)

        self
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      if @lc3.respond_to? method_name
        true
      else
        super
      end
    end

    private

    def assemble_and_load(name = 'lc3spec-tmp', &block)
      return nil unless block_given?

      f = Tempfile.new([name, '.asm'])
      begin
        yield f
        f.close

        ensure_assembled(f.path)
        prefix = f.path.chomp(File.extname(f.path))
        @lc3.file(prefix)

      ensure
        f.unlink

        # Try not to accidentally delete all files....
        unless prefix.nil? or prefix.empty?
          Dir.glob(prefix + '*') do |filename|
            File.unlink filename
          end
        end
      end
    end

    def ensure_present(filename)
      if filename.nil? or filename.empty?
        raise DoesNotAssembleError, 'Filename nil or empty'
      end

      # Copy file to current directory if needed
      basename = File.basename filename

      if Dir.glob(basename + '*').empty?
        if is_absolute_path?(filename)
          Dir.glob(filename + '') do |fn|
            FileUtils.cp(fn, '.')
          end
        else
          Dir.glob(File.join(@src_dir, filename + '*')) do |fn|
            FileUtils.cp(fn, '.')
          end
        end
      end

      # Check if we have the file now
      if Dir.glob(basename + '*').empty?
        raise DoesNotAssembleError, "Cannot find file #{basename}"
      end
    end

    def ensure_assembled(filename)
      if filename !~ /\.asm$/ and filename !~ /\.obj/
        asm_file = filename + '.asm'
        obj_file = filename + '.obj'

        # Always prefer finding .asm over .obj file
        if File.exist? asm_file
          filename = asm_file
        elsif File.exist? obj_file
          filename = obj_file
        else
          raise DoesNotAssembleError, "Cannot find #{asm_file} or #{obj_file}"
        end
      end

      # Check that the file assembles
      case filename
      when /\.asm$/
        error, status = Open3.capture2e('lc3as', filename)
        if not status.success?
          raise DoesNotAssembleError,
            "File does not assemble: #{filename}\n#{error}"
        end
      when /\.obj$/
        if File.size? filename
          success = true
        else
          raise DoesNotAssembleError,
            "File has zero size or does not exist: #{filename}"
        end
      end

      return true
    end
  end

end
