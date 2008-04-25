#!/usr/bin/env ruby -wKU

class RubyCompletion < Completion
  @scope    = "source.ruby"
  @language = "ruby"

  def suggestions
    line = ENV['TM_CURRENT_LINE']
    line = line[0..ENV['TM_LINE_INDEX'].to_i - 1]

    choices = []

    if line =~ /\b([A-Z]\w*)\.(\w*)$/
      prefix = $2.to_s
      functions_in_class_beginning_with($1, prefix).each do |method|
        next unless method['prototype'] =~ /self\./
        if method['name'] == 'initialize'
          method['name'] = 'new'
        end
        choices << method
      end
      choices << {'name' => 'new'} unless choices.find { |m| m['name'] == 'new' }
    elsif line =~ /\b([a-z]\w*)\.(\w*)$/
      prefix = $2.to_s
      variables_named($1).each do |variable|
        functions_in_class_beginning_with(variable['class'], prefix).each do |method|
          next if method['prototype'] =~ /self\./
          choices << method unless ['initialize'].include? method['name']
        end
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
      params = $1

      snippet = '('

      tabstop          = 0
      default_tabstops = 0
      snippet += params.scan(/([\w]+)(\s*=\s*.+?)?(,|$)/).map do |(name, default)|
        s = name
        optional = false

        if default
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
