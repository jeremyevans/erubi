unless defined?(TESTDIR)
  TESTDIR = File.dirname(__FILE__)
  LIBDIR  = TESTDIR == '.' ? '../lib' : File.dirname(TESTDIR) + '/lib'
  $: << TESTDIR
  $: << LIBDIR
end

require 'erubi'
require 'erubi/capture_end'
require 'benchmark/ips'

TEMPLATE = "
  <table>
   <tbody>
    <% i = 0
       list.each_with_index do |item, i| %>
    <tr>
     <td><%= i+1 %></td>
     <td><%== item %></td>
    </tr>
   <% end %>
   </tbody>
  </table>
"

Benchmark.ips do |x|
  x.time = 5
  x.warmup = 2

  x.report("string") do
    Erubi::Engine.new(TEMPLATE)
  end

  x.report("array") do |times|
    Erubi::Engine.new(TEMPLATE, src: [])
  end

  x.compare!
end


