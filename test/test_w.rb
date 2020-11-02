require 'warning'
Warning.ignore([:missing_ivar, :method_redefined, :not_reached, :unused_var], __dir__)
Warning.ignore(/void context/, __dir__)

$VERBOSE = true
require_relative 'test'
