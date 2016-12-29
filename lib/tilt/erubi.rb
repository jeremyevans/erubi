require 'tilt'
require 'tilt/template'
require 'erubi'

module Tilt
  # Erubi (a simplified version of Erubis) template implementation
  class ErubiTemplate < Template
    def prepare
      @options.merge!(:preamble => false, :postamble => false, :ensure=>true)

      engine_class = if @options[:engine_class]
        @options[:engine_class]
      elsif capture = @options[:capture]
        if capture == :explicit
          Erubi::CaptureEndEngine
        else
          Erubi::CaptureEngine
        end
      else
        Erubi::Engine
      end

      @engine = engine_class.new(data, @options)
      @outvar = @engine.bufvar
      @src = @engine.src.dup
      @engine
    end

    def precompiled_template(locals)
      @src
    end

    Tilt.register self, 'erb', 'rhtml', 'erubi'
  end
end
