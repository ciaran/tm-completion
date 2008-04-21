#!/usr/bin/env ruby -wKU

#!/usr/bin/env ruby 

require ENV['TM_BUNDLE_SUPPORT'] + '/lib/db'
require ENV['TM_BUNDLE_SUPPORT'] + '/lib/php'
require ENV['TM_SUPPORT_PATH'] + '/lib/ui'
require ENV['TM_SUPPORT_PATH'] + '/lib/exit_codes'
require ENV['TM_SUPPORT_PATH'] + '/lib/osx/plist'

line = ENV['TM_CURRENT_LINE']
line = line[0..ENV['TM_LINE_INDEX'].to_i - 1]

ProjectPath = ENV['TM_PROJECT_DIRECTORY']
DbPath      = ProjectPath + '/' + DatabaseFilename rescue nil
ParserPath  = ENV['TM_BUNDLE_SUPPORT'] + '/bin/parser.rb'

@current_file = parse_stdin

def variables_named(name)
  vars = []
  if ENV['TM_FILEPATH']
    vars += run_query("SELECT * FROM variables WHERE name = '#{name}' AND file != '#{e_sql ENV['TM_FILEPATH'].project_relative_path}';")
  end
  vars += @current_file[:variables].select { |v| v['name'] == name }
  vars
end

def functions_in_class_beginning_with(klass, prefix)
  functions = []
  if ENV['TM_FILEPATH']
    functions += run_query("SELECT * FROM functions WHERE class = '#{klass}' AND name LIKE '#{prefix}%' AND file != '#{e_sql ENV['TM_FILEPATH'].project_relative_path}';")
  end
  if @current_file[:functions]
    functions += @current_file[:functions].select { |f| f['name'].begins_with? prefix and f['class'] == klass }
  end
  functions
end

def functions_beginning_with(prefix)
  functions = []
  if ENV['TM_FILEPATH']
    functions += run_query("SELECT * FROM functions WHERE class = '' AND name LIKE '#{prefix}%' AND file != '#{e_sql ENV['TM_FILEPATH'].project_relative_path}';")
  end
  if @current_file[:functions]
    functions += @current_file[:functions].select { |f| f['name'].begins_with? prefix and f['class'] == nil }
  end
  functions
end

def snippet_for_method(method)
  prototype = method['prototype']

  snippet = '('

  parts = prototype.strip.match(/^\s*(?:([0-9A-Za-z|_]+)\s+)?(\w+)\s*\((.*)\).*$/)
  params = parts[3] rescue ''

  params = '' if params == 'void'

  tabstop          = 0
  default_tabstops = 0
  snippet += params.scan(/(\w+ )?&?([\w.|]+)( = .+?)?(\])?(,|$)/).map do |(type, name, default, optional_bracket)|
    s = type.to_s + name
    optional = false
    if optional_bracket
      # Optional
      s = '[' + s + ']'
      optional = true
    elsif default
      # Optional with default
      s = '[' + s + default + ']'
      optional = true
    end
    r = ""
    if optional
      default_tabstops += 1
      r << "${#{tabstop += 1}:"
    end
    tabstop += 1
    r << ", " if tabstop - default_tabstops > 1
    if default_tabstops > 0 and tabstop - default_tabstops == 1
      r << "#{s}"
    else
      r << "${#{tabstop}:#{s}}"
    end
    r
  end.join('')
  snippet << "}" * default_tabstops

  snippet + ')$0'
end

methods = []

if line =~ /(\$\w+)->(\w*)$/
  prefix = $2.to_s
  variables_named($1).each do |variable|
    functions_in_class_beginning_with(variable['class'], prefix).each do |method|
      methods << method unless [variable['class'], '__construct'].include? method['name']
    end
  end
  TextMate::exit_show_tool_tip "No methods found" if methods.empty?

  methods = methods.inject([]) { |methods, m| methods << m unless methods.include? m; methods }.sort_by { |m| m['name'].downcase }
elsif line =~ /(\$\w+)::(\w*)$/
  prefix = $2.to_s
  variables_named($1).each do |variable|
    functions_in_class_beginning_with(variable['class'], prefix).each do |method|
      methods << method unless [variable['class'], '__construct'].include? method['name']
    end
  end
  TextMate::exit_show_tool_tip "No methods found" if methods.empty?

  methods = methods.inject([]) { |methods, m| methods << m unless methods.include? m; methods }.sort_by { |m| m['name'].downcase }
else
  line = line[0..ENV['TM_LINE_INDEX'].to_i]
  line =~ /\b(\w*)$/
  prefix = $1.to_s

  functions_beginning_with(prefix).each do |method|
    methods << method
  end
  TextMate::exit_show_tool_tip "No functions found" if methods.empty?
end

TextMate::UI.complete(methods.map { |m| m.merge('display' => m['name']) }, :extra_chars => '_') do |method|
  snippet_for_method(method)
end
