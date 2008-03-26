#!/usr/bin/env ruby -wKU

#!/usr/bin/env ruby 

require ENV['TM_BUNDLE_SUPPORT'] + '/lib/db'
require ENV['TM_BUNDLE_SUPPORT'] + '/lib/php'
require ENV['TM_SUPPORT_PATH'] + '/lib/escape'
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
    functions += @current_file[:functions].select { |f| f['name'].begins_with? prefix and f['class'] == '' }
  end
  functions
end

def snippet_for_method(method)
  prototype = method['prototype']

  snippet = '('

  parts = prototype.strip.match(/^\s*(?:([0-9A-Za-z|_]+)\s+)?(\w+)\s*\((.*)\).*$/)
  params = parts[3] rescue ''

  params = '' if params == 'void'

  tabstop = 0
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
    tabstop += 1
    if tabstop > 1
      if optional
        "${#{tabstop}:, ${#{tabstop+=1}:#{s}}}"
      else
        ", ${#{tabstop}:#{s}}"
      end
    else
      "${#{tabstop}:#{s}}"
    end
  end.join('')

  snippet + ')$0'
end

methods = []

if line =~ /(\$\w+)->(\w*)/
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

if ENV['DIALOG'] !~ /2$/ or methods.size == 1
  if methods.size == 1
    choice = 0
  else
    abort unless choice = TextMate::UI.menu(methods.map { |m| m['name'] })
  end
  TextMate::exit_insert_snippet methods[choice]['name'][prefix.to_s.length..-1] + snippet_for_method(methods[choice])
else
  IO.popen("\"$DIALOG\" popup -c #{e_sh prefix} -e _ -i", 'w') do |io|
    io << {'suggestions' => methods.map do |method|
      {'title' => method['name'], 'snippet' => snippet_for_method(method)}
    end}.to_plist
  end
end
