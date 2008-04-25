#!/usr/bin/ruby -wKU

require "stringio"
require File.dirname(__FILE__) + "/../../lib/db"
require File.dirname(__FILE__) + "/../../lib/lexer"

file_path = ARGV[0]# || "/Users/ciaran/Library/Application Support/TextMate/Bundles/PHP Completion.tmbundle/Support/bin/complete.rb"

if file_path == '-'
  to_parse = STDIN
elsif file_path and file_path.size > 0
  to_parse = File.new(file_path)
else
  to_parse = DATA
end

lexer = Lexer.new do |l|
  l.add_token :line_comment,        %r{//|#}
  l.add_token :block_comment_start, %r{^=begin$}
  l.add_token :block_comment_end,   %r{^=end}
  l.add_token :class,               /^\s*(?:class)\s+(?:\w+)(?:\s*<\s*\w+)?/
  l.add_token :method,              /\bdef\s+(?:self\.)?\w+(?:\(.+?\))?/
  l.add_token :string,              /"(?:\\.|[^"\\])*"/
  l.add_token :return,              /\breturn\b/
  l.add_token :nil,                 /\bnil\b/
  l.add_token :open_block,          /do|\{/
  l.add_token :close_block,         /end|\}/
  # l.add_token :close,               /\)|\]|\}/
  # l.add_token :open,                /\(|\[|\{/
  l.add_token :terminator,          /;\n|\n/
  l.add_token :assignment,          /(?:@|@@|\$)?[a-z]\w*\s*=/
  l.add_token :new,                 /\b[A-Z]\w*\.new\b/
  l.add_token :operator,            /[&-+@\/==%:\,\?;<>\|.\~\^!]/
  l.add_token :identifier,          /\b[A-Za-z_0-9]+(?:\b|$)/
  l.add_token :number,              /\b\d+\b/
  l.add_token :whitespace,          /\s+/
  l.add_token :unknown,             /./
end
lexer.input { to_parse.gets }

Token = Struct.new(:tt, :text)

Token.module_eval do |foo|
  def inspect
    "<#{self[:tt]} \"#{self[:text]}\">"
  end
end

tokenList = []
lexer.each do |token| 
  next unless token.is_a? Array
  tokenList << Token.new(*token)
end

current_class = nil

classes     = {}
functions   = {}
variables   = {}
block_depth = 0
variable    = nil
comment     = nil

tokenList.each do |token|
  if comment
    if comment == :line_comment and token[:tt] == :terminator
      comment = nil
    elsif comment == :block_comment_start and token[:tt] == :block_comment_end
      comment = nil
    end
  else
    case token[:tt]
    when :open_block
      block_depth += 1
    when :close_block
      block_depth -= 1
      current_class = nil if current_class and block_depth == current_class[:depth]
    when :line_comment, :block_comment_start
      comment = token[:tt]
      phpdoc  = ''
    when :method
      token.text =~ /def\s+(?:self\.)?(\w+)/
      abort "Function regexp failed for #{token.text}" unless $1
      name = $1
      function_info = token.text
      if current_class
        classes[current_class[:name]][:methods][name] = function_info
      else
        functions[name] = function_info
      end
      block_depth += 1
    when :variable
      variable = token.text
    when :assignment
      if token.text =~ /^(.+?)\s*=/
        variable = $1
      end
      # keep variable
    when :new
      if variable
        token.text =~ /^(.+?)\.new/
        variables[variable] = $1
      end
    when :class
      token.text =~ /^class\s*(\w+)/
      abort "Class regexp failed" unless $1
      current_class = {:name => $1, :depth => block_depth}
      classes[$1] = {:methods => {}}
      block_depth += 1
    when :whitespace
      # Ignore
    else
      variable = nil
    end
  end
end

require "erb"
include ERB::Util

puts ERB.new(<<-XML).result
<?xml version="1.0" encoding="UTF-8"?>
<parsed file="<%=h file_path %>">
  <functions>
    <% functions.each_pair do |name, prototype| %>
      <function name="<%=h name %>" prototype="<%=h prototype %>" />
    <% end %>
  </functions>
  <classes>
    <% classes.each_pair do |name, info| %>
      <class name="<%= name %>">
        <% info[:methods].each_pair do |name, prototype| %>
          <method name="<%=h name %>" prototype="<%=h prototype %>"/>
        <% end %>
      </class>
    <% end %>
  </classes>
  <variables>
    <% variables.each_pair do |name, klass| %>
      <variable name="<%= name %>" type="<%= klass %>" />
    <% end %>
  </variables>
</parsed>
XML

__END__
class Completion
  @language    = nil
  @scope       = nil

  def initialize
    @current_file = parse_stdin(self.class.language)
  end

  def self.inherited(subclass)
    @completers ||= []
    @completers << subclass
  end

  def self.completers
    @completers
  end

  def self.scope
    @scope
  end

  def self.language
    @language
  end

  def current_file
    @current_file
  end
end

completer = Completion.new