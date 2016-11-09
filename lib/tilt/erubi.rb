require 'tilt'
require 'tilt/erb'
require 'erubi'

module Tilt
  # Erubi (a simplified version of Erubis) template implementation
  class ErubiTemplate < ERBTemplate
    def prepare
      @options.merge!(:preamble => false, :postamble => false)
      @engine = Erubi::Engine.new(data, @options)
      @outvar = @engine.bufvar
      @engine
    end

    def precompiled_preamble(locals)
      [super, "#{@outvar} = _buf = String.new"].join("\n")
    end

    def precompiled_postamble(locals)
      [@outvar, super].join("\n")
    end

    # Erubi doesn't have ERB's line-off-by-one under 1.9 problem.
    # Override and adjust back.
    if RUBY_VERSION >= '1.9.0'
      def precompiled(locals)
        source, offset = super
        [source, offset - 1]
      end
    end

    Tilt.register self, 'erb', 'rhtml', 'erubi'
  end
end
