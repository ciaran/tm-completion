#!/usr/bin/ruby -wKU

require "stringio"
require File.dirname(__FILE__) + "/../../lib/db"
require File.dirname(__FILE__) + "/../../lib/lexer"

file_path = ARGV[0] || "/Sites/quotes/includes/init.php"

if file_path == '-'
  to_parse = STDIN
else
  to_parse = File.new(file_path)
end

lexer = Lexer.new do |l|
  l.add_token :line_comment,        %r{//|#}
  l.add_token :phpdoc_start,        %r{/\*\*}
  l.add_token :block_comment_start, %r{/\*}
  l.add_token :block_comment_end,   %r{\*/}
  l.add_token :open_php,            /<\?(?:php\b)?/
  l.add_token :close_php,           /\?>/
  l.add_token :class,               /\b(?:class)\s*(?:\w+)(?:\s*extends\s*\w+)?(?=\s*\{)/
  l.add_token :property,            /\b(?:var|public|private|static)\s*\$\w+/
  l.add_token :function,            /\b(?:function)\s+&?\w+\s*\(.*?\)(?=\s*\{)/m
  l.add_token :string,              /"(?:\\.|[^"\\])*"/
  l.add_token :return,              /\breturn\b/
  l.add_token :nil,                 /\bnil\b/
  l.add_token :control,             /\b(?:if|while|for|do)(?:\s*)\(/
  l.add_token :variable,            /\$\w+\b/
  l.add_token :new,                 /\bnew\s+(?:\w+)/
  l.add_token :bind,                /(?:->)/
  l.add_token :post_op,             /\+\+|\-\-/
  l.add_token :open_block,          /\{/
  l.add_token :close_block,         /\}/
  l.add_token :close,               /\)|\]|\}/
  l.add_token :open,                /\(|\[|\{/
  l.add_token :terminator,          /;\n|\n/
  l.add_token :assignment,          /=\s*&?/
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

in_php = false

current_class = nil

classes     = {}
functions   = {}
variables   = {}
block_depth = 0
variable    = nil
comment     = nil
phpdoc      = ''

tokenList.each do |token|
  if in_php
    if comment
      if comment == :line_comment and token[:tt] == :terminator
        comment = nil
      elsif (comment == :block_comment_start or comment == :phpdoc_start) and token[:tt] == :block_comment_end
        comment = nil
      elsif comment == :phpdoc_start
        phpdoc << token[:text]
      end
    else
      case token[:tt]
      when :open_block
        block_depth += 1
      when :close_block
        block_depth -= 1
        current_class = nil if current_class and block_depth == current_class[:depth]
      when :line_comment, :block_comment_start, :phpdoc_start
        comment = token[:tt]
        phpdoc  = ''
      when :close_php
        in_php = false
      when :function
        # function_info = PHPFunction.new token.text
        token.text =~ /function\s+&?(\w+)\s*\(/
        abort "Function regexp failed for #{token.text}" unless $1
        name = $1
        abort token.text if $1 == 'if'
        function_info = token.text
        if current_class
          classes[current_class[:name]][:methods][name] = function_info
        else
          functions[name] = function_info
        end
      when :variable
        variable = token.text
      when :assignment
        # keep variable
        if phpdoc.length > 0 and phpdoc =~ /@var\s+(\w+)/ and not %w[string array integer boolean].include?($1)
          variables[variable] = $1
          phpdoc              = ''
        end
      when :new
        if variable
          token.text =~ /^new\s*(\w+)/
          variables[variable] = $1
        end
      when :class
        token.text =~ /^class\s*(\w+)/
        abort "Class regexp failed" unless $1
        current_class = {:name => $1, :depth => block_depth}
        classes[$1] = {:methods => {}}
      when :whitespace
        # Ignore
      else
        variable = nil
      end
    end
  elsif token[:tt] == :open_php
    in_php = true
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
<?php
function addPackageItem($type, $code) {
	$result = null;
	switch ($type) {
		case 'product':
			$product = new Product($code);
			if($product->Data) {
				$this->db->pquery('INSERT INTO packagecontents (packagecode, product) VALUES (?, ?)', $this->code, strtoupper($code));
			} else {
				$result = 'There is no product with that code';
			}
			break;
		case 'category':
			$prodcat = new ProductCategory($code);
			if($prodcat->Data) {
				$this->db->pquery('INSERT INTO packagecontents (packagecode, prodcat) VALUES (?, ?)', $this->code, strtoupper($code));
			} else {
				$result = 'There is no product category with that code';
			}
			break;
		case 'group':
			$prodgroup = new ProductGroup($code);
			if($prodgroup->Data) {
				$this->db->pquery('INSERT INTO packagecontents (packagecode, prodgr) VALUES (?, ?)', $this->code, strtoupper($code));
			} else {
				$result = 'There is no product group with that code';
			}
			break;
	}
	return $result;
}
