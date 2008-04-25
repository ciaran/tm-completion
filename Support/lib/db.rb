require "rexml/document"

unless defined?(e_sh)
  # escape text to make it useable in a shell script as one “word” (string)
  def e_sh(str)
  	str.to_s.gsub(/(?=[^a-zA-Z0-9_.\/\-\x7F-\xFF\n])/, '\\').gsub(/\n/, "'\n'").sub(/^$/, "''")
  end
end

DatabaseFilename = '.completion.db'
ResultSeparator  = '|'

class << Hash
  def create(keys, values)
    self[*keys.zip(values).flatten]
  end
end

def e_sql(value)
  return '' unless value
  # value.gsub(/(?=[\\'"])/, '\\')
  value.gsub("'", "''")
end

def database_exists?
  return false unless DbPath
  File.exists? DbPath
end

def run_query(sql)
  return [] if sql =~ /^\s*SELECT/i and not database_exists?

  # puts "Running #{sql}"
  result = nil
  IO.popen("sqlite3 -header -separator #{e_sh ResultSeparator} #{e_sh(DbPath)}", 'w+') do |io|
    io << sql
    io.close_write
    result = io.read
  end
  records = []
  unless result.empty?
    rows   = result.split("\n").reverse
    fields = rows.pop.split(ResultSeparator)
    while record = rows.pop
      records << Hash.create(fields, record.split(ResultSeparator))
    end
  end
  records
end

def parse_stdin(language)
  IO.popen("ruby #{e_sh ParserPath + "/" + language + ".rb"} -", "w+") do |io|
    io << STDIN.read
    io.close_write
    parse_xml io.read
  end
end

def parse_file(path, language)
  parse_xml %x{ruby #{e_sh ParserPath + "/" + language + ".rb"} #{e_sh path}}
end

class String
  def begins_with?(prefix)
    self =~ /^#{Regexp.quote prefix}/
  end

  def project_relative_path
    if begins_with? ProjectPath
      path = self[ProjectPath.length..-1] 
    else
      path = self
    end
    path = path[1..-1] if path[0] == ?/
    path
  end
end

def parse_xml(xml)
  functions = []
  classes   = []
  variables = []

  doc = REXML::Document.new(xml)
  doc.elements.each('/parsed/functions/function') do |function|
    functions << {'name' => function.attributes['name'], 'prototype' => function.attributes['prototype']}
  end
  doc.elements.each('/parsed/classes/class') do |klass|
    classes << {'name' => klass.attributes['name']}
    klass.elements.each do |method|
      functions << {'name' => method.attributes['name'], 'prototype' => method.attributes['prototype'], 'class' => klass.attributes['name']}
    end
  end
  doc.elements.each('/parsed/variables/variable') do |var|
    variables << {'name' => var.attributes['name'], 'class' => var.attributes['type']}
  end
  {:functions => functions, :classes => classes, :variables => variables}
end
