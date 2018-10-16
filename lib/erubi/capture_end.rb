# frozen_string_literal: true

require 'erubi'

module Erubi
  # An engine class that supports capturing blocks via the <%|= and <%|== tags,
  # explicitly ending the captures using <%| end %> blocks.
  class CaptureEndEngine < Engine
    # Initializes the engine.  Accepts the same arguments as ::Erubi::Engine, and these
    # additional options:
    # :escape_capture :: Whether to make <%|= escape by default, and <%|== not escape by default,
    #                    defaults to the same value as :escape.
    # :return_buffer :: Whether to return the buffer itself or the last expression of the block,
    #                   defaults to false.
    def initialize(input, properties={})
      properties = Hash[properties]
      escape = properties.fetch(:escape){properties.fetch(:escape_html, false)}
      @escape_capture = properties.fetch(:escape_capture, escape)
      @return_buffer = properties.fetch(:return_buffer, false)
      @bufval = properties[:bufval] ||= 'String.new'
      @bufstack = '__erubi_stack'
      properties[:regexp] ||= /<%(\|?={1,2}|-|\#|%|\|)?(.*?)([-=])?%>([ \t]*\r?\n)?/m
      super
    end

    private

    # Handle the <%|= and <%|== tags
    def handle(indicator, code, tailch, rspace, lspace)
      case indicator
      when '|=', '|=='
        rspace = nil if tailch && !tailch.empty?
        add_text(lspace) if lspace
        escape_capture = !((indicator == '|=') ^ @escape_capture)
        src << "begin; (#{@bufstack} ||= []) << #{@bufvar}; #{@bufvar} = #{@bufval}; #{@bufstack}.last << #{@escapefunc if escape_capture}((" << code
        add_text(rspace) if rspace
      when '|'
        rspace = nil if tailch && !tailch.empty?
        add_text(lspace) if lspace
        result = @return_buffer ? "; #{@bufvar}; " : ""
        src << code << result << ")).to_s; ensure; #{@bufvar} = #{@bufstack}.pop; end;"
        add_text(rspace) if rspace
      else
        super
      end
    end
  end
end
