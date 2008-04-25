#!/usr/bin/env ruby -wKU

require ENV['TM_SUPPORT_PATH'] + '/lib/ui'
require ENV['TM_SUPPORT_PATH'] + '/lib/exit_codes'
require ENV['TM_SUPPORT_PATH'] + '/lib/osx/plist'
require ENV['TM_BUNDLE_SUPPORT'] + '/lib/db'
require ENV['TM_BUNDLE_SUPPORT'] + '/lib/php'

line = ENV['TM_CURRENT_LINE']
line = line[0..ENV['TM_LINE_INDEX'].to_i - 1]

ProjectPath = ENV['TM_PROJECT_DIRECTORY']
DbPath      = ProjectPath + '/' + DatabaseFilename rescue nil
ParserPath  = ENV['TM_BUNDLE_SUPPORT'] + '/bin/parsers/'

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

  def suggestions
    []
  end

  def snippet_for_item(item)
  end

private
  # Utility methods
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
  
  def classes_beginning_with(prefix)
    classes = []
    if ENV['TM_FILEPATH']
      classes += run_query("SELECT * FROM classes WHERE name LIKE '#{prefix}%' AND file != '#{e_sql ENV['TM_FILEPATH'].project_relative_path}';")
    end
    if @current_file[:classes]
      classes += @current_file[:classes].select { |c| c['name'].begins_with? prefix }
    end
    classes
  end
end

Dir[File.dirname(__FILE__) + "/completers/*"].each { |parser| require parser }

Completion.completers.each do |klass|
  if ENV['TM_SCOPE'] =~ /#{Regexp.quote klass.scope}/m
    completer = klass.new

    choices = completer.suggestions
    if choices.empty?
      abort "No suggestions found"
    else
      choices = choices.inject([]) { |choices, item| choices << item unless choices.include? item; choices }.sort_by { |item| item['name'].downcase }
      if choices.empty?
      else
        TextMate::UI.complete(choices.map { |m| m.merge('display' => m['name']) }, :extra_chars => '_') do |choice|
          completer.snippet_for_item(choice)
        end
      end
    end

    exit
  end
end

puts "Completion not available for #{ENV['TM_SCOPE']}"
