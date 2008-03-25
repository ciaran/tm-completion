class PHPFunction
  def initialize(prototype)
    @parts = prototype.strip.match(/^\s*(?:([0-9A-Za-z|_]+)\s+)?(\w+)\s*\((.*)\).*$/)
  end
  
  def params
    params = @parts[3] rescue ''

    params.scan(/\s*(\w+ )?(&?[\w.|]+)(?:\s*=\s*(.+?))?(\])?\s*(?:,|$)/).map do |(type, name, default, optional_bracket)|
      param = type.to_s + name
      optional = false
      if optional_bracket
        # Optional
        param = '[' + param + ']'
        optional = true
      elsif default
        # Optional with default
        param = '[' + param + ' = ' + default + ']'
        optional = true
      end
      {
        :param => param,
        :type => type.to_s.strip,
        :name => name.to_s,
        :optional => optional,
        :default => default
      }
    end
  end
  
  def name
    @parts[2]
  end
  
  def type
    @parts[1]
  end
end

if __FILE__ == $0
  require "test/unit"
  
  class PHPFunctionTest < Test::Unit::TestCase
    def test_no_args
      f = PHPFunction.new('function test()')
      assert_equal "test", f.name
      assert_equal 0, f.params.size
    end

    def test_single_arg
      f = PHPFunction.new('function test($foo)')
      assert_equal "test", f.name
      assert_equal 1, f.params.size

      param = f.params[0]
      assert_equal 'foo', param[:name]
      assert_equal false, param[:optional]
      assert_equal nil, param[:default]
    end

    def test_single_arg_with_defaults
      f = PHPFunction.new('function single($bar = 1)')
      assert_equal "single", f.name
      assert_equal 1, f.params.size

      param = f.params[0]
      assert_equal 'bar', param[:name]
      assert_equal true, param[:optional]
      assert_equal '1', param[:default]
    end

    def test_multiple_args
      f = PHPFunction.new('function multi($bar, $foo = "qux", $baz = array())')
      assert_equal "multi", f.name
      p f.params
      assert_equal 3, f.params.size

      param = f.params[0]
      assert_equal 'bar', param[:name]
      assert_equal false, param[:optional]
      assert_equal nil, param[:default]

      param = f.params[1]
      assert_equal 'foo', param[:name]
      assert_equal true, param[:optional]
      assert_equal '"qux"', param[:default]

      param = f.params[2]
      assert_equal 'baz', param[:name]
      assert_equal true, param[:optional]
      assert_equal 'array()', param[:default]
    end
  end
end
