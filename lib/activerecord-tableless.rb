# See #ActiveRecord::Tableless
require 'activerecord-tableless/version'

module ActiveRecord

  # = ActiveRecord::Tableless
  #
  # Allow classes to behave like ActiveRecord models, but without an associated
  # database table. A great way to capitalize on validations. Based on the
  # original post at http://www.railsweenie.com/forums/2/topics/724 (which seems
  # to have disappeared from the face of the earth).
  #
  # = Example usage
  #
  #  class ContactMessage < ActiveRecord::Base
  #
  #    has_no_table
  #
  #    column :name,    :string
  #    column :email,   :string
  #    column :message, :string
  #
  #  end
  #
  #  msg = ContactMessage.new( params[:msg] )
  #  if msg.valid?
  #    ContactMessageSender.deliver_message( msg )
  #    redirect_to :action => :sent
  #  end
  #
  module Tableless
    require 'active_record'

    class NoDatabase < StandardError; end
    class Unsupported < StandardError; end

    def self.included( base ) #:nodoc:
      base.send :extend, ActsMethods
    end

    module ActsMethods #:nodoc:

      # A model that needs to be tableless will call this method to indicate
      # it.
      def has_no_table(options = {:database => :fail_fast})
        raise ArgumentError.new("Invalid database option '#{options[:database]}'") unless [:fail_fast, :pretend_success].member? options[:database]
        # keep our options handy
        class_attribute :tableless_options
        self.tableless_options = {
          :database => options[:database],
          :columns_hash => {}
        }

        # extend
        extend  ActiveRecord::Tableless::SingletonMethods
        extend  ActiveRecord::Tableless::ClassMethods

        # include
        include ActiveRecord::Tableless::InstanceMethods

        # setup columns
        include ActiveModel::AttributeAssignment
        include ActiveRecord::ModelSchema
      end

      def tableless?
        false
      end

    end

    module SingletonMethods

      # Used internally by ActiveRecord 5.  This is the special hook that makes everything else work.
      def load_schema!
        @columns_hash = tableless_options[:columns_hash].except(*ignored_columns)
        @columns_hash.each do |name, column|
          define_attribute(
              name,
              connection.lookup_cast_type_from_column(column),
              default: column.default,
              user_provided_default: false
          )
        end
      end

      # Register a new column.
      def column(name, sql_type = nil, default = nil, null = true)
        cast_type = "ActiveRecord::Type::#{sql_type.to_s.camelize}".constantize.new
        tableless_options[:columns_hash][name.to_s] = ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, cast_type, sql_type.to_s, null)
      end

      # Register a set of columns with the same SQL type
      def add_columns(sql_type, *args)
        args.each do |col|
          column col, sql_type
        end
      end

      def destroy(*args)
        case tableless_options[:database]
        when :pretend_success
          self.new()
        when :fail_fast
          raise NoDatabase.new("Can't #destroy on Tableless class")
        end
      end

      def destroy_all(*_args)
        case tableless_options[:database]
        when :pretend_success
          []
        when :fail_fast
          raise NoDatabase.new("Can't #destroy_all on Tableless class")
        end
      end

      case ActiveRecord::VERSION::MAJOR
      when 5
        def find_by_sql(*args)
          case tableless_options[:database]
          when :pretend_success
            []
          when :fail_fast
            raise NoDatabase.new("Can't #find_by_sql on Tableless class")
          end

        end
      else
        raise Unsupported.new("Unsupported ActiveRecord version")
      end

      def transaction(&block)
#        case tableless_options[:database]
#        when :pretend_success
          @_current_transaction_records ||= []
          yield
#        when :fail_fast
#          raise NoDatabase.new("Can't #transaction on Tableless class")
#        end
      end

      def tableless?
        true
      end

      def table_exists?
        false
      end
    end

    module ClassMethods

      def from_query_string(query_string)
        unless query_string.blank?
          params = query_string.split('&').collect do |chunk|
            next if chunk.empty?
            key, value = chunk.split('=', 2)
            next if key.empty?
            value = value.nil? ? nil : CGI.unescape(value)
            [ CGI.unescape(key), value ]
          end.compact.to_h

          new(params)
        else
          new
        end
      end

      def connection
        conn = Object.new()
        def conn.quote_table_name(*_args)
          ""
        end
        def conn.quote_column_name(*_args)
          ""
        end
        def conn.substitute_at(*_args)
          nil
        end
        def conn.schema_cache(*_args)
          schema_cache = Object.new()
          def schema_cache.columns_hash(*_args)
            Hash.new()
          end
          schema_cache
        end
        # Fixes Issue #17. https://github.com/softace/activerecord-tableless/issues/17
        # The following method is from the ActiveRecord gem: /lib/active_record/connection_adapters/abstract/database_statements.rb .
        # Sanitizes the given LIMIT parameter in order to prevent SQL injection.
        #
        # The +limit+ may be anything that can evaluate to a string via #to_s. It
        # should look like an integer, or a comma-delimited list of integers, or
        # an Arel SQL literal.
        #
        # Returns Integer and Arel::Nodes::SqlLiteral limits as is.
        # Returns the sanitized limit parameter, either as an integer, or as a
        # string which contains a comma-delimited list of integers.
        def conn.sanitize_limit(limit)
          if limit.is_a?(Integer) || limit.is_a?(Arel::Nodes::SqlLiteral)
            limit
          elsif limit.to_s.include?(',')
            Arel.sql limit.to_s.split(',').map{ |i| Integer(i) }.join(',')
          else
            Integer(limit)
          end
        end

        # Called by bound_attributes in /lib/active_record/relation/query_methods.rb
        # Returns a SQL string with the from, join, where, and having clauses, in addition to the limit and offset.
        def conn.combine_bind_parameters(**_args)
          ""
        end

        def conn.lookup_cast_type_from_column(*_args)
          lct = Object.new
          def lct.assert_valid_value(*_args)
            true
          end
          # Needed for Rails 5.0
          def lct.serialize(args)
            args
          end
          def lct.deserialize(args)
            args
          end
          def lct.cast(args)
            args
          end
          def lct.changed?(*_args)
            false
          end
          def lct.changed_in_place?(*_args)
            false
          end
          lct
        end

        # This is used in the StatementCache object. It returns an object that
        # can be used to query the database repeatedly.
        def conn.cacheable_query(arel) # :nodoc:
          if prepared_statements
            ActiveRecord::StatementCache.query visitor, arel.ast
          else
            ActiveRecord::StatementCache.partial_query visitor, arel.ast, collector
          end
        end
        conn
      end

    end

    module InstanceMethods

      def to_query_string(prefix = nil)
        attributes.to_a.collect{|(name,value)| escaped_var_name(name, prefix) + "=" + escape_for_url(value) if value }.compact.join("&")
      end

      def quote_value(_value, _column = nil)
        ""
      end

      %w(create create_record _create_record update update_record _update_record).each do |method_name|
        define_method(method_name) do |*args|
          case self.class.tableless_options[:database]
          when :pretend_success
            true
          when :fail_fast
            raise NoDatabase.new("Can't ##{method_name} a Tableless object")
          end
        end
      end

      def destroy
        case self.class.tableless_options[:database]
        when :pretend_success
          @destroyed = true
          freeze
        when :fail_fast
          raise NoDatabase.new("Can't #destroy a Tableless object")
        end
      end

      def reload(*args)
        case self.class.tableless_options[:database]
        when :pretend_success
          self
        when :fail_fast
          raise NoDatabase.new("Can't #reload a Tableless object")
        end
      end

      def add_to_transaction
      end

      private

        def escaped_var_name(name, prefix = nil)
          prefix ? "#{URI.escape(prefix)}[#{URI.escape(name)}]" : URI.escape(name)
        end

        def escape_for_url(value)
          case value
            when true then "1"
            when false then "0"
            when nil then ""
            else URI.escape(value.to_s)
          end
        rescue
          ""
        end

    end

  end
end

ActiveRecord::Base.send( :include, ActiveRecord::Tableless )
