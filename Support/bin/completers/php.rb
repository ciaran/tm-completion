#!/usr/bin/env ruby -wKU

class PhpCompletion < Completion
  @scope    = "source.php"
  @language = "php"

  def suggestions
    line = ENV['TM_CURRENT_LINE']
    line = line[0..ENV['TM_LINE_INDEX'].to_i - 1]
    
    choices = []

    if line =~ /(\$\w+)->(\w*)$/
      prefix = $2.to_s
      variables_named($1).each do |variable|
        functions_in_class_beginning_with(variable['class'], prefix).each do |method|
          choices << method unless [variable['class'], '__construct'].include? method['name']
        end
      end
    elsif line =~ /(\w+)::(\w*)$/
      prefix = $2.to_s
      functions_in_class_beginning_with($1, prefix).each do |method|
        choices << method unless [$1, '__construct'].include? method['name']
      end
    else
      line = line[0..ENV['TM_LINE_INDEX'].to_i]
      line =~ /\b(\w*)$/
      prefix = $1.to_s
    
      functions_beginning_with(prefix).each do |method|
        choices << method
      end
      classes_beginning_with(prefix).each do |klass|
        choices << klass
      end
    end
    choices
  end

  def snippet_for_item(item)
    if item.has_key?('prototype') and item['prototype'] =~ /\((.+?)\)$/
      snippet = '('
    
      parts = item['prototype'].strip.match(/^\s*(?:([0-9A-Za-z|_]+)\s+)?(\w+)\s*\((.*)\).*$/)
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
  end
end
