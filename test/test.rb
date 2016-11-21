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
    start do
      add_filter "/test/"
      add_group('Missing'){|src| src.covered_percent < 100}
      add_group('Covered'){|src| src.covered_percent == 100}
    end
  end
end

require 'erubi'
require 'erubi/capture'
require 'tilt/erubi'
require 'minitest/spec'
require 'minitest/autorun'

describe Erubi::Engine do
  before do
    @options = {}
  end

  def check_output(input, src, result, &block)
    t = (@options[:engine] || Erubi::Engine).new(input, @options)
    eval(t.src, block.binding).must_equal result
    t.src.gsub("'.freeze;", "';").must_equal src
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

  it "should handle no options" do
    list = ['&\'<>"2']
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
_buf = String.new; _buf << '<table>
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
   <td>&amp;&#039;&lt;&gt;&quot;2</td>
  </tr>
 </tbody>
</table>
1
END3
  end

  it "should handle ensure option" do
    list = ['&\'<>"2']
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
begin; __original_outvar = @a if defined?(@a); @a = String.new; @a << '<table>
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
   <td>&amp;&#039;&lt;&gt;&quot;2</td>
  </tr>
 </tbody>
</table>
1
END3
    @a.must_equal 'bar'
  end

  [['', false], ['=', true]].each do |ind, escape|
    it "should allow <%|=#{ind} for capturing without escaping when :escape_capture => #{escape}" do
      @options[:bufvar] = '@a'
      @options[:capture] = true
      @options[:escape_capture] = escape
      @options[:escape] = !escape
      @options[:engine] = ::Erubi::CaptureEngine
      setup_foo
      check_output(<<END1, <<END2, <<END3){}
<table>
 <tbody>
  <%|=#{ind} @foo.bar do %>
  <tr>
   <td><%=#{ind} 1 %></td>
   <td><%=#{ind} '&' %></td>
  </tr>
 <% end %>
 </tbody>
</table>
END1
#{'__erubi = ::Erubi;' unless escape}@a = ::Erubi::Buffer.new; @a << '<table>
 <tbody>
'; @a << '  '; @a.before_append!; @a.append=  @foo.bar do  @a << '
'; @a << '  <tr>
   <td>'; @a << #{!escape ? '__erubi' : '::Erubi'}.h(( 1 )); @a << '</td>
   <td>'; @a << #{!escape ? '__erubi' : '::Erubi'}.h(( '&' )); @a << '</td>
  </tr>
';  end 
 @a << ' </tbody>
</table>
';
@a.to_s
END2
<table>
 <tbody>
  A
  <TR>
   <TD>1</TD>
   <TD>&AMP;</TD>
  </TR>
B </tbody>
</table>
END3
    end
  end

  [['', true], ['=', false]].each do |ind, escape|
    it "should allow <%|=#{ind} for capturing with escaping when :escape => #{escape}" do
      @options[:bufvar] = '@a'
      @options[:capture] = true
      @options[:escape] = escape
      @options[:engine] = ::Erubi::CaptureEngine
      setup_foo
      check_output(<<END1, <<END2, <<END3){}
<table>
 <tbody>
  <%|=#{ind} @foo.bar do %>
   <b><%=#{ind} '&' %></b>
 <% end %>
 </tbody>
</table>
END1
#{'__erubi = ::Erubi;' if escape}@a = ::Erubi::Buffer.new; @a << '<table>
 <tbody>
'; @a << '  '; @a.before_append!; @a.escape=  @foo.bar do  @a << '
'; @a << '   <b>'; @a << #{escape ? '__erubi' : '::Erubi'}.h(( '&' )); @a << '</b>
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
  end

  [:outvar, :bufvar].each do |var|
    it "should handle :#{var} and :freeze options" do
      @options[var] = "@_out_buf"
      @options[:freeze] = true
      @items = [2]
      i = 0
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
@_out_buf = String.new; @_out_buf << '<table>
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
    i = 0
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
_buf = String.new; _buf << '<table>
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

  it "should handle :trim => false option" do
    @options[:trim] = false
    @items = [2]
    i = 0
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
  <% i %>a
  <% i %>
</table>
END1
_buf = String.new; _buf << '<table>
'; _buf << '  '; for item in @items ; _buf << '
'; _buf << '  <tr>
    <td>';

 _buf << '</td>
    <td>'; _buf << ::Erubi.h(( item )); _buf << '</td>
  </tr>
'; _buf << '  '; end ;
 _buf << '
'; _buf << '  '; i ; _buf << 'a
'; _buf << '  '; i ; _buf << '
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
      h = proc{|s| s.to_s*2}
      list = ['2']
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
_buf = String.new; _buf << '<table>
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
  end

  it "should handle :escape option without :escapefunc option" do
    @options[:escape] = true
    list = ['&\'<>"2']
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
__erubi = ::Erubi;_buf = String.new; _buf << '<table>
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
   <td>&amp;&#039;&lt;&gt;&quot;2</td>
  </tr>
 </tbody>
</table>
END3
  end

  it "should handle :preamble and :postamble options" do
    @options[:preamble] = '_buf = String.new("1");'
    @options[:postamble] = "_buf[0...18]\n"
    list = ['2']
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
  end

  it "should have working filename accessor" do
    Erubi::Engine.new('', :filename=>'foo.rb').filename.must_equal 'foo.rb'
  end

  it "should have working bufvar accessor" do
    Erubi::Engine.new('', :bufvar=>'foo').bufvar.must_equal 'foo'
    Erubi::Engine.new('', :outvar=>'foo').bufvar.must_equal 'foo'
  end

  it "should return frozen object" do
    Erubi::Engine.new('').frozen?.must_equal true
  end

  it "should have frozen src" do
    Erubi::Engine.new('').src.frozen?.must_equal true
  end

  it "should raise an error if a tag is not handled when a custom regexp is used" do
    proc{Erubi::Engine.new('<%] %>', :regexp =>/<%(={1,2}|\]|-|\#|%)?(.*?)([-=])?%>([ \t]*\r?\n)?/m)}.must_raise ArgumentError
    proc{Erubi::CaptureEngine.new('<%] %>', :regexp =>/<%(={1,2}|\]|-|\#|%)?(.*?)([-=])?%>([ \t]*\r?\n)?/m)}.must_raise ArgumentError
  end

  it "should have working tilt support" do
    @list = ['&\'<>"2']
    Tilt::ErubiTemplate.new{<<END1}.render(self).must_equal(<<END2)
<table>
 <tbody>
  <% i = 0
     @list.each_with_index do |item, i| %>
  <tr>
   <td><%= i+1 %></td>
   <td><%== item %></td>
  </tr>
 <% end %>
 </tbody>
</table>
<%== i+1 %>
END1
<table>
 <tbody>
  <tr>
   <td>1</td>
   <td>&amp;&#039;&lt;&gt;&quot;2</td>
  </tr>
 </tbody>
</table>
1
END2
  end

  it "should have working tilt support for capturing" do
    setup_foo
    Tilt::ErubiTemplate.new(:capture=>true, :outvar=>'@a'){<<END1}.render(self).must_equal(<<END2)
1<%|= @foo.bar do %>bar<% end %>2
END1
1ABARB2
END2
  end

  it "should have working tilt support for specifying engine class" do
    setup_foo
    @a = 1
    Tilt::ErubiTemplate.new(:engine_class=>Erubi::CaptureEngine, :outvar=>'@a'){<<END1}.render(self).must_equal(<<END2)
1<%|= @foo.bar do %>bar<% end %>2
END1
1ABARB2
END2
    @a.must_equal 1
  end

  it "should have working tilt support for locals" do
    Tilt::ErubiTemplate.new{<<END1}.render(self, :b=>3).must_equal(<<END2)
<%= b %>
END1
3
END2
  end
end
