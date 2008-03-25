class Lexer
  include Enumerable
  def initialize
    @label   = nil
    @pattern = nil
    @handler = nil
    @input   = nil
    
    reset
    
    yield self if block_given?
  end
  
  def input(&reader)
    if @input.is_a? self.class
      @input.input(&reader)
    else
      class << reader
        alias_method :next, :call
      end
      
      @input = reader
    end
  end
  
  def add_token(label, pattern, &handler)
    unless @label.nil?
      @input = clone
    end
    
    @label   = label
    @pattern = /(#{pattern})/
    @handler = handler || lambda { |label, match| [label, match] }
    
    reset
  end
  
  def next(peek = false)
    while @tokens.empty? and not @finished
      new_input = @input.next
      if new_input.nil? or new_input.is_a? String
        @buffer    += new_input unless new_input.nil?
        new_tokens =  @buffer.split(@pattern)
        while new_tokens.size > 2 or (new_input.nil? and not new_tokens.empty?)
          @tokens << new_tokens.shift
          @tokens << @handler[@label, new_tokens.shift] unless new_tokens.empty?
        end
        @buffer   = new_tokens.join
        @finished = true if new_input.nil?
      else
        separator, new_token = @buffer.split(@pattern)
        new_token            = @handler[@label, new_token] unless new_token.nil?
        @tokens.push( *[ separator,
                         new_token,
                         new_input ].select { |t| not t.nil? and t != "" } )
        reset(:buffer)
      end
    end
    peek ? @tokens.first : @tokens.shift
  end
  
  def peek
    self.next(true)
  end
  
  def each
    while token = self.next
      yield token
    end
  end
  
  private
  
  def reset(*attrs)
    @buffer   = String.new if attrs.empty? or attrs.include? :buffer
    @tokens   = Array.new  if attrs.empty? or attrs.include? :tokens
    @finished = false      if attrs.empty? or attrs.include? :finished
  end
end