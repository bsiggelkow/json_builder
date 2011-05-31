require 'rubygems'
require 'blankslate' unless defined? BlankSlate
require 'json'

module JSONBuilder
  class Generator < BlankSlate
    def initialize(options=nil)
      @pretty_print ||= options.delete(:pretty) if !options.nil? && options[:pretty] # don't want nil
      @compiled = []
      @indent = 0
      @passed_items = 0
      @indent_next = false
      @is_array = false
    end

    def inspect
      compile!
    end

    #
    # Using +tag!+ is neccessary when dynamic keys are needed
    # 
    #     json.tag! 
    #
    def tag!(sym, *args, &block)
      method_missing(sym.to_sym, *args, &block)
    end

    def array!(set, &block)
      @array_length = set.length if set.respond_to?(:length)
      @is_array = true
      method_missing(nil, nil, &block)
    end

    def array_item!(&block)
      method_missing(nil, nil, &block)

      @passed_items += 1
      @compiled << '},{' if @passed_items < @array_length
    end

    def method_missing(sym, *args, &block)
      text = type_cast(args.first)

      if block
        start_block(sym) unless sym.nil?
        block.call(self)
        end_block unless sym.nil?
      else
        if @indent_next
          @compiled[@compiled.length-1] = @compiled.last + "\"#{sym}\":#{text}"
          @indent_next = false
        else
          @compiled << "\"#{sym}\": #{text}"
        end
      end
    end

    def compile!
      # If there is no JSON, no need for an array
      if @is_array
        if @compiled.length > 0
          compiled = ('[{' + @compiled.join(',') + '}]').gsub(',},{,', '},{')
        else
          # No need to make this pretty
          @pretty_print = false
          compiled = '[]'
        end
      else
        compiled = '{' + @compiled.join(', ') + '}'
      end

      if @pretty_print
        JSON.pretty_generate(JSON[compiled])
      else
        compiled
      end
    end

    # Since most methods here are public facing,
    private
      def type_cast(text)
        case text
          when Array then '['+ text.map! { |j| type_cast(j) }.join(', ') +']'
          when Hash then loop_hash(text)
          when String then "\"#{text.gsub('"', '\"')}\""
          when TrueClass then 'true'
          when FalseClass then 'false'
          when NilClass then 'null'
          when DateTime, Time, Date then "\"#{text.strftime('%Y-%m-%dT%H:%M:%S%z')}\""
          when Fixnum, Bignum, Float then text
        end
      end
      
      def loop_hash(hash)
        compiled_hash = []
        
        hash.each do |key, value|
          compiled_hash << "\"#{key.to_s}\": #{type_cast(value)}"
        end
        
        '{' + compiled_hash.join(', ') + '}'
      end

      def start_indent
        @indent += 1
      end

      def end_indent
        @indent -= 1
      end

      def start_block(sym)
        start_indent
        @indent_next = true
        @compiled << "\"#{sym}\":{"
      end

      def end_block
        if @indent > 0
          @compiled[@compiled.length-1] = @compiled.last + '}'
        else
          @compiled << '}'
        end
      end
    end
end
