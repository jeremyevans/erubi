# frozen_string_literal: true

require 'erubi'

module Erubi
  # A buffer class used for templates that support captures
  class Buffer
    def initialize
      @bufs = [new_buffer]
    end

    # Return the current buffer
    def buffer
      @bufs.last
    end

    # Append to the current buffer
    def <<(str)
      buffer << str
    end

    # Add a new buffer, that future appends will go to.
    def before_append!
      @bufs << new_buffer
    end

    # Take the current buffer and append it to the previous buffer.
    def append=(_)
      buf = @bufs.pop
      buffer << buf.to_s
    end

    # Escape the current buffer and append it to the previous buffer,
    def escape=(_)
      buf = @bufs.pop
      buffer << escape(buf.to_s)
    end

    # Return the current buffer, as a string.
    def to_s
      buffer.to_s
    end

    private

    # An object to use for the underlying buffers.
    def new_buffer
      String.new
    end

    # HTML/XML escape the given string.
    def escape(str)
      ::Erubi.h(str)
    end
  end

  # An engine class that supports capturing blocks via the <%|= and <%|== tags.
  class CaptureEngine < Engine
    # Initializes the engine.  Accepts the same arguments as ::Erubi::Engine, and these
    # additional options:
    # :escape_capture :: Whether to make <%|= escape by default, and <%|== not escape by default,
    #                    defaults to the same value as :escape.
    def initialize(input, properties={})
      properties = Hash[properties]
      escape = properties.fetch(:escape){properties.fetch(:escape_html, false)}
      @escape_capture = properties.fetch(:escape_capture, escape)
      properties[:regexp] ||= /<%(\|?={1,2}|-|\#|%)?(.*?)([-=])?%>([ \t]*\r?\n)?/m
      properties[:bufval] ||= "::Erubi::Buffer.new"
      super
    end

    private

    # Handle the <%|= and <%|== tags
    def handle(indicator, code, tailch, rspace, lspace)
      case indicator
      when '|=', '|=='
        rspace = nil if tailch && !tailch.empty?
        add_text(lspace) if lspace
        meth = ((indicator == '|=') ^ @escape_capture) ? 'append' : 'escape'
        src << " #{@bufvar}.before_append!; #{@bufvar}.#{meth}= " << code
        add_text(rspace) if rspace
      else
        super
      end
    end
  end
end
