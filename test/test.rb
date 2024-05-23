require 'rubygems'

unless defined?(TESTDIR)
  TESTDIR = File.dirname(__FILE__)
  LIBDIR  = TESTDIR == '.' ? '../lib' : File.dirname(TESTDIR) + '/lib'
  $: << TESTDIR
  $: << LIBDIR
end

if ENV['COVERAGE']
  require 'coverage'
  require 'simplecov'

  ENV.delete('COVERAGE')
  SimpleCov.instance_eval do
    enable_coverage :branch

    start do
      add_filter "/test/"
      add_group('Missing'){|src| src.covered_percent < 100}
      add_group('Covered'){|src| src.covered_percent == 100}
    end
  end
end

require 'erubi'
require 'erubi/capture_end'
require 'erubi/capture_block'

ENV['MT_NO_PLUGINS'] = '1' # Work around stupid autoloading of plugins
gem 'minitest'
require 'minitest/global_expectations/autorun'

describe 'Erubi' do
  before do
    @options = {}
  end

  def check_output(input, src, result, &block)
    t = @engine.new(input, @options)
    tsrc = t.src
    eval(tsrc, block.binding).must_equal result
    return if @engine <= Erubi::CaptureBlockEngine && !@check_src
    strip_freeze = defined?(@strip_freeze) ? @strip_freeze : RUBY_VERSION >= '2.1'
    tsrc = tsrc.gsub(/\.freeze/, '') if strip_freeze
    tsrc.must_equal src
  end

  def setup_foo
    @foo = Object.new
    @foo.instance_variable_set(:@t, self)
    def self.a; @a; end
    def @foo.bar
      @t.a << "a"
      yield
      @t.a << 'b'
      @t.a.buffer.upcase!
    end
  end

  def setup_bar
    if @engine <= Erubi::CaptureBlockEngine
      def self.bar(&block)
        "a#{@a.capture(&block)}b".upcase
      end
      def self.baz(&block)
        "c#{@a.capture(&block)}d" * 2
      end
      def self.quux(&block)
        v = 3.times.map do |i|
          "c#{i}#{@a.capture(i, &block)}d#{i}"
        end.join
        "a#{v}b".upcase
      end
    else
      def self.bar
        @a << "a"
        yield
        @a << 'b'
        @a.upcase
      end
      def self.baz
        @a << "c"
        yield
        @a << 'd'
        @a * 2
      end
      def self.quux
        @a << "a"
        3.times do |i|
          @a << "c#{i}"
          yield i
          @a << "d#{i}"
        end
        @a << "b"
        @a.upcase
      end
    end
  end

  {'Engine'=>Erubi::Engine, 'CaptureEndEngine'=>Erubi::CaptureEndEngine, 'CaptureBlockEngine'=>Erubi::CaptureBlockEngine}.each do |desc, engine|
    describe desc do
      before do
        @engine = engine
      end

      it "should handle no tags with frozen source" do
        check_output(<<END1.freeze, <<END2, <<END3){}
a
END1
_buf = ::String.new; _buf << 'a
';
_buf.to_s
END2
a
END3
      end

      it "should handle no options" do
        list = list = ['&\'<>"2']
        check_output(<<END1, <<END2, <<END3){}
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
<%== i+1 %>
END1
_buf = ::String.new; _buf << '<table>
 <tbody>
';   i = 0
     list.each_with_index do |item, i| 
 _buf << '  <tr>
   <td>'; _buf << ( i+1 ).to_s; _buf << '</td>
   <td>'; _buf << ::Erubi.h(( item )); _buf << '</td>
  </tr>
';  end 
 _buf << ' </tbody>
</table>
'; _buf << ::Erubi.h(( i+1 )); _buf << '
';
_buf.to_s
END2
<table>
 <tbody>
  <tr>
   <td>1</td>
   <td>&amp;&#39;&lt;&gt;&quot;2</td>
  </tr>
 </tbody>
</table>
1
END3
      end

      it "should escape all backslashes and apostrophes in text" do
        list = list = ['&\'<>"2']
        check_output(<<END1.chomp, <<END2, <<END3){}
<table>
 <tbody>' ' \\ \\
  <% i = 0
     list.each_with_index do |item, i| %>
  <tr>
   <td><%= i+1 -%>
</td>
   <td><%== item %></td>
  </tr>
 <% end %>
 </tbody>
</table>
<%== i+1 %>
<%
%>
END1
_buf = ::String.new; _buf << '<table>
 <tbody>\\' \\' \\\\ \\\\
';   i = 0
     list.each_with_index do |item, i| 
 _buf << '  <tr>
   <td>'; _buf << ( i+1 ).to_s; _buf << '</td>
   <td>'; _buf << ::Erubi.h(( item )); _buf << '</td>
  </tr>
';  end 
 _buf << ' </tbody>
</table>
'; _buf << ::Erubi.h(( i+1 )); _buf << '
';
_buf.to_s
END2
<table>
 <tbody>' ' \\ \\
  <tr>
   <td>1</td>
   <td>&amp;&#39;&lt;&gt;&quot;2</td>
  </tr>
 </tbody>
</table>
1
END3
      end

      it "should strip only whitespace for <%, <%- and <%# tags" do
        check_output(<<END1, <<END2, <<END3){}
  <% a = 1 %>  
a
  <%- a = 2 %>  
b
  <%# a = 3 %>  
c
 /<% a = 1 %>  
a
/ <%- a = 2 %>  
b
//<%# a = 3 %>  
c
  <% a = 1 %> /
a
  <%- a = 2 %>/ 
b
  <%# a = 3 %>//
c
END1
_buf = ::String.new;   a = 1   
 _buf << 'a
';   a = 2   
 _buf << 'b
';
 _buf << 'c
 /'; a = 1 ; _buf << '  
'; _buf << 'a
/ '; a = 2 ; _buf << '  
'; _buf << 'b
//';
 _buf << '  
'; _buf << 'c
'; _buf << '  '; a = 1 ; _buf << ' /
a
'; _buf << '  '; a = 2 ; _buf << '/ 
b
'; _buf << '  ';; _buf << '//
c
';
_buf.to_s
END2
a
b
c
 /  
a
/   
b
//  
c
   /
a
  / 
b
  //
c
END3
      end

      it "should handle ensure option" do
        list = list = ['&\'<>"2']
        @options[:ensure] = true
        @options[:bufvar] = '@a'
        @a = 'bar'
        check_output(<<END1, <<END2, <<END3){}
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
<%== i+1 %>
END1
begin; __original_outvar = @a#{' if defined?(@a)' if RUBY_VERSION < '3'}; @a = ::String.new; @a << '<table>
 <tbody>
';   i = 0
     list.each_with_index do |item, i| 
 @a << '  <tr>
   <td>'; @a << ( i+1 ).to_s; @a << '</td>
   <td>'; @a << ::Erubi.h(( item )); @a << '</td>
  </tr>
';  end 
 @a << ' </tbody>
</table>
'; @a << ::Erubi.h(( i+1 )); @a << '
';
@a.to_s
; ensure
  @a = __original_outvar
end
END2
<table>
 <tbody>
  <tr>
   <td>1</td>
   <td>&amp;&#39;&lt;&gt;&quot;2</td>
  </tr>
 </tbody>
</table>
1
END3
        @a.must_equal 'bar'
      end

      it "should handle chain_appends option" do
        @options[:chain_appends] = true
        list = list = ['&\'<>"2']
        check_output(<<END1, <<END2, <<END3){}
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
<%== i+1 %>
END1
_buf = ::String.new;; _buf << '<table>
 <tbody>
';    i = 0
     list.each_with_index do |item, i| 
; _buf << '  <tr>
   <td>' << ( i+1 ).to_s << '</td>
   <td>' << ::Erubi.h(( item )) << '</td>
  </tr>
';   end 
; _buf << ' </tbody>
</table>
' << ::Erubi.h(( i+1 )) << '
'
; _buf.to_s
END2
<table>
 <tbody>
  <tr>
   <td>1</td>
   <td>&amp;&#39;&lt;&gt;&quot;2</td>
  </tr>
 </tbody>
</table>
1
END3
      end

      it "should handle :freeze_template_literals => true option" do
        @options[:freeze_template_literals] = true
        list = list = ['&\'<>"2']
        @strip_freeze = false
        check_output(<<END1, <<END2, <<END3){}
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
<%== i+1 %>
END1
_buf = ::String.new; _buf << '<table>
 <tbody>
'.freeze;   i = 0
     list.each_with_index do |item, i| 
 _buf << '  <tr>
   <td>'.freeze; _buf << ( i+1 ).to_s; _buf << '</td>
   <td>'.freeze; _buf << ::Erubi.h(( item )); _buf << '</td>
  </tr>
'.freeze;  end 
 _buf << ' </tbody>
</table>
'.freeze; _buf << ::Erubi.h(( i+1 )); _buf << '
'.freeze;
_buf.to_s
END2
<table>
 <tbody>
  <tr>
   <td>1</td>
   <td>&amp;&#39;&lt;&gt;&quot;2</td>
  </tr>
 </tbody>
</table>
1
END3
      end

      it "should handle :freeze_template_literals => false option" do
        @options[:freeze_template_literals] = false
        list = list = ['&\'<>"2']
        @strip_freeze = false
        check_output(<<END1, <<END2, <<END3){}
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
<%== i+1 %>
END1
_buf = ::String.new; _buf << '<table>
 <tbody>
';   i = 0
     list.each_with_index do |item, i| 
 _buf << '  <tr>
   <td>'; _buf << ( i+1 ).to_s; _buf << '</td>
   <td>'; _buf << ::Erubi.h(( item )); _buf << '</td>
  </tr>
';  end 
 _buf << ' </tbody>
</table>
'; _buf << ::Erubi.h(( i+1 )); _buf << '
';
_buf.to_s
END2
<table>
 <tbody>
  <tr>
   <td>1</td>
   <td>&amp;&#39;&lt;&gt;&quot;2</td>
  </tr>
 </tbody>
</table>
1
END3
      end

      it "should handle ensure option with no bufvar" do
        list = list = ['&\'<>"2']
        @options[:ensure] = true
        check_output(<<END1, <<END2, <<END3){}
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
<%== i+1 %>
END1
begin; __original_outvar = _buf if defined?(_buf); _buf = ::String.new; _buf << '<table>
 <tbody>
';   i = 0
     list.each_with_index do |item, i| 
 _buf << '  <tr>
   <td>'; _buf << ( i+1 ).to_s; _buf << '</td>
   <td>'; _buf << ::Erubi.h(( item )); _buf << '</td>
  </tr>
';  end 
 _buf << ' </tbody>
</table>
'; _buf << ::Erubi.h(( i+1 )); _buf << '
';
_buf.to_s
; ensure
  _buf = __original_outvar
end
END2
<table>
 <tbody>
  <tr>
   <td>1</td>
   <td>&amp;&#39;&lt;&gt;&quot;2</td>
  </tr>
 </tbody>
</table>
1
END3
      end

      [:outvar, :bufvar].each do |var|
        it "should handle :#{var} and :freeze options" do
          @options[var] = "@_out_buf"
          @options[:freeze] = true
          @items = [2]
          i = i = 0
          check_output(<<END1, <<END2, <<END3){}
<table>
  <% for item in @items %>
  <tr>
    <td><%= i+1 %></td>
    <td><%== item %></td>
  </tr>
  <% end %>
</table>
END1
# frozen_string_literal: true
@_out_buf = ::String.new; @_out_buf << '<table>
';   for item in @items 
 @_out_buf << '  <tr>
    <td>'; @_out_buf << ( i+1 ).to_s; @_out_buf << '</td>
    <td>'; @_out_buf << ::Erubi.h(( item )); @_out_buf << '</td>
  </tr>
';   end 
 @_out_buf << '</table>
';
@_out_buf.to_s
END2
<table>
  <tr>
    <td>1</td>
    <td>2</td>
  </tr>
</table>
END3
        end
      end

      it "should handle <%% and <%# syntax" do
        @items = [2]
        i = i = 0
        check_output(<<END1, <<END2, <<END3){}
<table>
<%% for item in @items %>
  <tr>
    <td><%# i+1 %></td>
    <td><%# item %></td>
  </tr>
  <%% end %>
</table>
END1
_buf = ::String.new; _buf << '<table>
'; _buf << '<% for item in @items %>
'; _buf << '  <tr>
    <td>';; _buf << '</td>
    <td>';; _buf << '</td>
  </tr>
'; _buf << '  <% end %>
'; _buf << '</table>
';
_buf.to_s
END2
<table>
<% for item in @items %>
  <tr>
    <td></td>
    <td></td>
  </tr>
  <% end %>
</table>
END3
      end

      it "should handle <%% with a different literal prefix/postfix" do
        @options[:literal_prefix] = "{%"
        @options[:literal_postfix] = "%}"
        @items = [2]
        i = i = 0
        check_output(<<END1, <<END2, <<END3){}
<table>
  <%% for item in @items %>
  <tr>
  </tr>
  <%% end %>
  <%%= "literal" %>
</table>
END1
_buf = ::String.new; _buf << '<table>
'; _buf << '  {% for item in @items %}
'; _buf << '  <tr>
  </tr>
'; _buf << '  {% end %}
'; _buf << '  {%= "literal" %}
'; _buf << '</table>
';
_buf.to_s
END2
<table>
  {% for item in @items %}
  <tr>
  </tr>
  {% end %}
  {%= "literal" %}
</table>
END3
      end

      it "should handle :trim => false option" do
        @options[:trim] = false
        @items = [2]
        i = i = 0
        check_output(<<END1, <<END2, <<END3){}
<table>
  <% for item in @items %>
  <tr>
    <td><%# 
    i+1
    %></td>
    <td><%== item %></td>
  </tr>
  <% end %><%#%>
  <% i = 1 %>a
  <% i = 1 %>
</table>
END1
_buf = ::String.new; _buf << '<table>
'; _buf << '  '; for item in @items ; _buf << '
'; _buf << '  <tr>
    <td>';

 _buf << '</td>
    <td>'; _buf << ::Erubi.h(( item )); _buf << '</td>
  </tr>
'; _buf << '  '; end ;
 _buf << '
'; _buf << '  '; i = 1 ; _buf << 'a
'; _buf << '  '; i = 1 ; _buf << '
'; _buf << '</table>
';
_buf.to_s
END2
<table>
  
  <tr>
    <td></td>
    <td>2</td>
  </tr>
  
  a
  
</table>
END3
      end

      [:escape, :escape_html].each do  |opt|
        it "should handle :#{opt} and :escapefunc options" do
          @options[opt] = true
          @options[:escapefunc] = 'h.call'
          h = h = proc{|s| s.to_s*2}
          list = list = ['2']
          check_output(<<END1, <<END2, <<END3){}
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
<%== i+1 %>
END1
_buf = ::String.new; _buf << '<table>
 <tbody>
';   i = 0
     list.each_with_index do |item, i| 
 _buf << '  <tr>
   <td>'; _buf << h.call(( i+1 )); _buf << '</td>
   <td>'; _buf << ( item ).to_s; _buf << '</td>
  </tr>
';  end 
 _buf << ' </tbody>
</table>
'; _buf << ( i+1 ).to_s; _buf << '
';
_buf.to_s
END2
<table>
 <tbody>
  <tr>
   <td>11</td>
   <td>2</td>
  </tr>
 </tbody>
</table>
1
END3
        end
      end unless engine == Erubi::CaptureBlockEngine

      it "should handle :escape option without :escapefunc option" do
        @options[:escape] = true
        list = list = ['&\'<>"2']
        check_output(<<END1, <<END2, <<END3){}
<table>
 <tbody>
  <% i = 0
     list.each_with_index do |item, i| %>
  <tr>
   <td><%== i+1 %></td>
   <td><%= item %></td>
  </tr>
 <% end %>
 </tbody>
</table>
END1
__erubi = ::Erubi; _buf = ::String.new; _buf << '<table>
 <tbody>
';   i = 0
     list.each_with_index do |item, i| 
 _buf << '  <tr>
   <td>'; _buf << ( i+1 ).to_s; _buf << '</td>
   <td>'; _buf << __erubi.h(( item )); _buf << '</td>
  </tr>
';  end 
 _buf << ' </tbody>
</table>
';
_buf.to_s
END2
<table>
 <tbody>
  <tr>
   <td>1</td>
   <td>&amp;&#39;&lt;&gt;&quot;2</td>
  </tr>
 </tbody>
</table>
END3
      end

      it "should handle :preamble and :postamble options" do
        @options[:preamble] = '_buf = String.new("1");'
        @options[:postamble] = "_buf[0...18]\n"
        list = list = ['2']
        check_output(<<END1, <<END2, <<END3){}
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
<%== i+1 %>
END1
_buf = String.new("1"); _buf << '<table>
 <tbody>
';   i = 0
     list.each_with_index do |item, i| 
 _buf << '  <tr>
   <td>'; _buf << ( i+1 ).to_s; _buf << '</td>
   <td>'; _buf << ::Erubi.h(( item )); _buf << '</td>
  </tr>
';  end 
 _buf << ' </tbody>
</table>
'; _buf << ::Erubi.h(( i+1 )); _buf << '
';
_buf[0...18]
END2
1<table>
 <tbody>
END3
      end unless engine == Erubi::CaptureBlockEngine

      it "should have working filename accessor" do
        engine.new('', :filename=>'foo.rb').filename.must_equal 'foo.rb'
      end

      it "should have working bufvar accessor" do
        engine.new('', :bufvar=>'foo').bufvar.must_equal 'foo'
        engine.new('', :outvar=>'foo').bufvar.must_equal 'foo'
      end

      it "should work with BasicObject methods" do
        c = Class.new(BasicObject)
        c.class_eval("def a; #{engine.new('2').src} end")
        c.new.a.must_equal '2'
      end if defined?(BasicObject)

      it "should return frozen object" do
        engine.new('').frozen?.must_equal true
      end

      it "should have frozen src" do
        engine.new('').src.frozen?.must_equal true
      end

      it "should raise an error if a tag is not handled when a custom regexp is used" do
        proc{engine.new('<%] %>', :regexp =>/<%(={1,2}|\]|-|\#|%)?(.*?)([-=])?%>([ \t]*\r?\n)?/m)}.must_raise ArgumentError
      end
    end
  end

  # Hack to allow CaptureEndEngine tests to pass with minimal changes on CaptureBlock engine
  capture_block_engine = Class.new(::Erubi::CaptureBlockEngine) do
    def initialize(input, opts={})
      input = input.gsub('<%|', '<%')
      super
    end
  end

  {
    ::Erubi::CaptureEndEngine=>'CaptureEndEngine',
    capture_block_engine=>'CaptureBlockEngine'
  }.each do |engine, desc|
    describe desc do
      before do
        @engine = engine
      end

      if engine == capture_block_engine
        def self.it(desc)
          desc = desc.gsub('<%|', '<%')
          super
        end
      else
        space = ' '
        nl = "\n"
      end

      it "should handle trailing rspace with - modifier in <%|= and <%|" do
        eval(@engine.new("<%|= '&' -%>\n<%| -%>\n").src).must_equal '&'
      end

      it "should handle lspace in <%|=" do
        eval(@engine.new("<%|= %><%| %><%|= %><%| %>").src).must_equal ''
      end

      it "should have <%|= not escape by default" do
        eval(@engine.new('<%|= "&" %><%| %>').src).must_equal '&'
        eval(@engine.new('<%|= "&" %><%| %>', :escape=>false).src).must_equal '&'
        eval(@engine.new('<%|= "&" %><%| %>', :escape=>true).src).must_equal '&amp;'
      end

      it "should have <%|== escape by default" do
        eval(@engine.new('<%|== "&" %><%| %>').src).must_equal '&amp;'
        eval(@engine.new('<%|== "&" %><%| %>', :escape=>true).src).must_equal '&'
        eval(@engine.new('<%|== "&" %><%| %>', :escape=>false).src).must_equal '&amp;'
      end

      it "should have <%|= and <%|== respect :escape_capture option" do
        eval(@engine.new('<%|= "&" %><%| %>', :escape_capture=>false).src).must_equal '&'
        eval(@engine.new('<%|= "&" %><%| %>', :escape_capture=>true).src).must_equal '&amp;'
        eval(@engine.new('<%|== "&" %><%| %>', :escape_capture=>true).src).must_equal '&'
        eval(@engine.new('<%|== "&" %><%| %>', :escape_capture=>false).src).must_equal '&amp;'
      end unless engine == capture_block_engine

      [['', false], ['=', true]].each do |ind, escape|
        it "should allow <%|=#{ind} and <%| for capturing with :escape_capture => #{escape} and :escape => #{!escape}" do
          @options[:bufvar] = '@a'
          @options[:capture] = true
          @options[:escape_capture] = escape
          @options[:escape] = !escape
          setup_bar
          check_output(<<END1, <<END2, <<END3){}
<table>
 <tbody>
  <%|=#{ind} bar do %>
   <b><%=#{ind} '&' %></b>
 <%| end %>
 </tbody>
</table>
END1
#{'__erubi = ::Erubi; ' unless escape}@a = ::String.new; @a << '<table>
 <tbody>
'; @a << '  ';begin; (__erubi_stack ||= []) << @a; @a = ::String.new; __erubi_stack.last << (( bar do  @a << '
'; @a << '   <b>'; @a << #{!escape ? '__erubi' : '::Erubi'}.h(( '&' )); @a << '</b>
'; @a << ' '; end )).to_s; ensure; @a = __erubi_stack.pop; end; @a << '
'; @a << ' </tbody>
</table>
';
@a.to_s
END2
<table>
 <tbody>
  A
   <B>&AMP;</B>
 B
 </tbody>
</table>
END3
        end
      end unless engine == capture_block_engine

      [['', true], ['=', false]].each do |ind, escape|
        it "should allow <%|=#{ind} and <%| for capturing when with :escape => #{escape}" do
          @options[:bufvar] = '@a'
          @options[:escape] = escape
          setup_bar
          check_output(<<END1, <<END2, <<END3){}
<table>
 <tbody>
  <%|=#{ind} bar do %>
   <b><%=#{ind} '&' %></b>
 <%| end %>
 </tbody>
</table>
END1
#{'__erubi = ::Erubi; ' if escape}@a = ::String.new; @a << '<table>
 <tbody>
'; @a << '  ';begin; (__erubi_stack ||= []) << @a; @a = ::String.new; __erubi_stack.last << #{escape ? '__erubi' : '::Erubi'}.h(( bar do  @a << '
'; @a << '   <b>'; @a << #{escape ? '__erubi' : '::Erubi'}.h(( '&' )); @a << '</b>
'; @a << ' '; end )).to_s; ensure; @a = __erubi_stack.pop; end; @a << '
'; @a << ' </tbody>
</table>
';
@a.to_s
END2
<table>
 <tbody>
  A
   &lt;B&gt;&amp;AMP;&lt;/B&gt;
#{space}B#{nl} </tbody>
</table>
END3
        end

        it "should handle loops in <%|=#{ind} and <%| for capturing when with :escape => #{escape}" do
          @options[:bufvar] = '@a'
          @options[:escape] = escape
          setup_bar
          check_output(<<END1, <<END2, <<END3){}
<table>
 <tbody>
  <%|=#{ind} quux do |i| %>
   <b><%=#{ind} "\#{i}&" %></b>
 <%| end %>
 </tbody>
</table>
END1
#{'__erubi = ::Erubi; ' if escape}@a = ::String.new; @a << '<table>
 <tbody>
'; @a << '  ';begin; (__erubi_stack ||= []) << @a; @a = ::String.new; __erubi_stack.last << #{escape ? '__erubi' : '::Erubi'}.h(( quux do |i|  @a << '
'; @a << '   <b>'; @a << #{escape ? '__erubi' : '::Erubi'}.h(( "\#{i}&" )); @a << '</b>
'; @a << ' '; end )).to_s; ensure; @a = __erubi_stack.pop; end; @a << '
'; @a << ' </tbody>
</table>
';
@a.to_s
END2
<table>
 <tbody>
  AC0
   &lt;B&gt;0&amp;AMP;&lt;/B&gt;
#{space}D0C1
   &lt;B&gt;1&amp;AMP;&lt;/B&gt;
#{space}D1C2
   &lt;B&gt;2&amp;AMP;&lt;/B&gt;
#{space}D2B#{nl} </tbody>
</table>
END3
        end

        it "should allow <%|=#{ind} and <%| for nested capturing when with :escape => #{escape}" do
          @options[:bufvar] = '@a'
          @options[:escape] = escape
          setup_bar
          check_output(<<END1, <<END2, <<END3){}
<table>
 <tbody>
  <%|=#{ind} bar do %>
   <b><%=#{ind} '&' %></b>
   <%|=#{ind} baz do %>e<%| end %>
 <%| end %>
 </tbody>
</table>
END1
#{'__erubi = ::Erubi; ' if escape}@a = ::String.new; @a << '<table>
 <tbody>
'; @a << '  ';begin; (__erubi_stack ||= []) << @a; @a = ::String.new; __erubi_stack.last << #{escape ? '__erubi' : '::Erubi'}.h(( bar do  @a << '
'; @a << '   <b>'; @a << #{escape ? '__erubi' : '::Erubi'}.h(( '&' )); @a << '</b>
'; @a << '   ';begin; (__erubi_stack ||= []) << @a; @a = ::String.new; __erubi_stack.last << #{escape ? '__erubi' : '::Erubi'}.h(( baz do  @a << 'e'; end )).to_s; ensure; @a = __erubi_stack.pop; end; @a << '
'; @a << ' '; end )).to_s; ensure; @a = __erubi_stack.pop; end; @a << '
'; @a << ' </tbody>
</table>
';
@a.to_s
END2
<table>
 <tbody>
  A
   &lt;B&gt;&amp;AMP;&lt;/B&gt;
   CEDCED
#{space}B#{nl} </tbody>
</table>
END3
        end
      end

      next if engine == capture_block_engine

      it "should respect the :yield_returns_buffer option for making templates return the (potentially modified) buffer" do
        @options[:bufvar] = '@a'

        def self.bar
          a = String.new
          a << "a"
          yield 'burgers'
          case b = (yield 'salads')
          when String
            a << b
            a << 'b'
            a.upcase
          end
        end

        check_output(<<END1, <<END2, <<END3){}
<%|= bar do |item| %>
Let's eat <%= item %>!
<% nil %><%| end %>
END1
@a = ::String.new;begin; (__erubi_stack ||= []) << @a; @a = ::String.new; __erubi_stack.last << (( bar do |item|  @a << '
'; @a << 'Let\\'s eat '; @a << ( item ).to_s; @a << '!
'; nil ; end )).to_s; ensure; @a = __erubi_stack.pop; end; @a << '
';
@a.to_s
END2

END3

      @options[:yield_returns_buffer] = true

      check_output(<<END1, <<END2, <<END3) {}
<%|= bar do |item| %>
Let's eat <%= item %>!
<% i = i = nil %><%| end %>
END1
@a = ::String.new;begin; (__erubi_stack ||= []) << @a; @a = ::String.new; __erubi_stack.last << (( bar do |item|  @a << '
'; @a << 'Let\\'s eat '; @a << ( item ).to_s; @a << '!
'; i = i = nil ; @a;  end )).to_s; ensure; @a = __erubi_stack.pop; end; @a << '
';
@a.to_s
END2
A
LET'S EAT BURGERS!

LET'S EAT SALADS!
B
END3
      end

      it "should respect the :yield_returns_buffer option for making templates return the (potentially modified) buffer as the result of the block" do
        @options[:yield_returns_buffer] = true

        def self.bar(foo = nil)
          if foo.nil?
            yield
          else
            foo
          end
        end

        check_output(<<END1, <<END2, <<END3) {}
<%|= bar do %>
Let's eat the tacos!
<%| end %>

Delicious!
END1
_buf = ::String.new;begin; (__erubi_stack ||= []) << _buf; _buf = ::String.new; __erubi_stack.last << (( bar do  _buf << '
'; _buf << 'Let\\'s eat the tacos!
'; _buf;  end )).to_s; ensure; _buf = __erubi_stack.pop; end; _buf << '
'; _buf << '
Delicious!
';
_buf.to_s
END2

Let's eat the tacos!


Delicious!
END3

      check_output(<<END1, <<END2, <<END3) {}
<%|= bar("Don't eat the burgers!") do %>
Let's eat burgers!
<%| end %>

Delicious!
END1
_buf = ::String.new;begin; (__erubi_stack ||= []) << _buf; _buf = ::String.new; __erubi_stack.last << (( bar(\"Don't eat the burgers!\") do  _buf << '
'; _buf << 'Let\\'s eat burgers!
'; _buf;  end )).to_s; ensure; _buf = __erubi_stack.pop; end; _buf << '
'; _buf << '
Delicious!
';
_buf.to_s
END2
Don't eat the burgers!

Delicious!
END3
      end
    end
  end

  describe 'Erubi::CaptureBlockEngine' do
    before do
      @engine = Erubi::CaptureBlockEngine
      @check_src = true
    end

    it "should handle empty tags by concatening empty string" do
      check_output(<<END1, <<END2, <<END3){}
<%= %><%== %>
END1
_buf = ::Erubi::CaptureBlockEngine::Buffer.new; _buf <<= '' ; _buf |= '' ; _buf << '
';
_buf.to_s
END2

END3
    end

    it "should work as specified in documentation" do
      @options[:bufvar] = '@a'
      def self.upcase_form(&block)
        "<form>#{@a.capture(&block).upcase}</form>"
      end
      check_output(<<END1, <<END2, <<END3){}
<%= upcase_form do %>
  <%= 'foo' %>
<% end %>

END1
@a = ::Erubi::CaptureBlockEngine::Buffer.new; @a <<=  upcase_form do ; @a << '
'; @a << '  '; @a <<=  'foo' ; @a << '
'; end 
 @a << '
';
@a.to_s
END2
<form>
  FOO
</form>
END3
  end

    [['', true], ['=', false]].each do |ind, escape|
      it "should allow <%=#{ind} and <% for escaped capturing with :escape => #{escape}" do
        @options[:bufvar] = '@a'
        @options[:escape] = escape
        setup_bar
        check_output(<<END1, <<END2, <<END3){}
<table>
 <tbody>
  <%=#{ind} bar do %>
   <b><%=#{ind} '&' %></b>
 <% end %>
 </tbody>
</table>
END1
#{'__erubi = ::Erubi; ' if escape}@a = ::Erubi::CaptureBlockEngine::Buffer.new; @a << '<table>
 <tbody>
  '; @a |=  bar do ; @a << '
'; @a << '   <b>'; @a |=  '&' ; @a << '</b>
';  end 
 @a << ' </tbody>
</table>
';
@a.to_s
END2
<table>
 <tbody>
  A
   &lt;B&gt;&amp;AMP;&lt;/B&gt;
B </tbody>
</table>
END3
     end

      it "should allow <%=#{ind} and <% for unescaped capturing when with :escape => #{!escape}" do
        @options[:bufvar] = '@a'
        @options[:escape] = !escape
        setup_bar
        check_output(<<END1, <<END2, <<END3){}
<table>
 <tbody>
  <%=#{ind} bar do %>
   <b><%=#{ind} '&' %></b>
 <% end %>
 </tbody>
</table>
END1
#{'__erubi = ::Erubi; ' if !escape}@a = ::Erubi::CaptureBlockEngine::Buffer.new; @a << '<table>
 <tbody>
  '; @a <<=  bar do ; @a << '
'; @a << '   <b>'; @a <<=  '&' ; @a << '</b>
';  end 
 @a << ' </tbody>
</table>
';
@a.to_s
END2
<table>
 <tbody>
  A
   <B>&</B>
B </tbody>
</table>
END3
     end
    end
  end

end
