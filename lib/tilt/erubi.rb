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
      elsif @options[:capture]
        Erubi::CaptureEngine
      else
        Erubi::Engine
      end

      @engine = engine_class.new(data, @options)
      @outvar = @engine.bufvar
      @engine
    end

    def precompiled_template(locals)
      @engine.src
    end

    Tilt.register self, 'erb', 'rhtml', 'erubi'
  end
end
