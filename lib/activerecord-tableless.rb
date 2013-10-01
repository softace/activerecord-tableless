# See #ActiveRecord::Tableless

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

    class Exception < StandardError
    end
    class NoDatabase < Exception
    end

    def self.included( base ) #:nodoc:
      base.send :extend, ActsMethods
    end

    module ActsMethods #:nodoc:

      # A model that needs to be tableless will call this method to indicate
      # it.
      def has_no_table(options = {:database => :fail_fast})
        raise ArgumentError.new("Invalid database option '#{options[:database]}'") unless [:fail_fast, :pretend_success].member? options[:database]
        # keep our options handy
        if ActiveRecord::VERSION::STRING < "3.1.0"
          write_inheritable_attribute(:tableless_options,
                                      { :database => options[:database],
                                        :columns => []
                                      }
                                      )
          class_inheritable_reader :tableless_options
        elsif ActiveRecord::VERSION::STRING >= "3.2.0"
          class_attribute :tableless_options
          self.tableless_options = {
            :database => options[:database],
            :columns => []
          }
        else
          raise Exception.new("Sorry, ActiveRecord version #{ActiveRecord::VERSION::STRING} is not supported")
        end

        # extend
        extend  ActiveRecord::Tableless::SingletonMethods
        extend  ActiveRecord::Tableless::ClassMethods

        # include
        include ActiveRecord::Tableless::InstanceMethods

        # setup columns
      end

      def tableless?
        false
      end

    end

    module SingletonMethods

      # Return the list of columns registered for the model. Used internally by
      # ActiveRecord
      def columns
        tableless_options[:columns]
      end

      # Register a new column.
      def column(name, sql_type = nil, default = nil, null = true)
        tableless_options[:columns] << ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, sql_type.to_s, null)
      end

      # Register a set of colums with the same SQL type
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

      def destroy_all(*args)
        case tableless_options[:database]
        when :pretend_success
          []
        when :fail_fast
          raise NoDatabase.new("Can't #destroy_all on Tableless class")
        end
      end

      case ActiveRecord::VERSION::MAJOR
      when 2
        def find_from_ids(*args)
          case tableless_options[:database]
          when :pretend_success
            raise ActiveRecord::RecordNotFound.new("Couldn't find #{self} with ID=#{args[0].to_s}")

          when :fail_fast
            raise NoDatabase.new("Can't #find_from_ids on Tableless class")
          end
        end

        def find_every(*args)
          case tableless_options[:database]
          when :pretend_success
            []
          when :fail_fast
            raise NoDatabase.new("Can't #find_every on Tableless class")
          end
        end
      when 3
        def all(*args)
          case tableless_options[:database]
          when :pretend_success
            []
          when :fail_fast
            raise NoDatabase.new("Can't #find_every on Tableless class")
          end

        end
      when 4
        def find_by_sql(*args)
          case tableless_options[:database]
          when :pretend_success
            []
          when :fail_fast
            raise NoDatabase.new("Can't #find_by_sql on Tableless class")
          end

        end
      else
        raise Exception.new("Unsupported ActiveRecord version")
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

      if ActiveRecord::VERSION::MAJOR < 3
      else
        def table_exists?
          false
        end
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
        def conn.quote_table_name(*args)
          ""
        end
        def conn.substitute_at(*args)
          nil
        end
        def conn.schema_cache(*args)
          schema_cache = Object.new()
          def schema_cache.columns_hash(*args)
            Hash.new()
          end
          schema_cache
        end
        conn
      end

    end

    module InstanceMethods

      def to_query_string(prefix = nil)
        attributes.to_a.collect{|(name,value)| escaped_var_name(name, prefix) + "=" + escape_for_url(value) if value }.compact.join("&")
      end

      def quote_value(value, column = nil)
        ""
      end

      def create(*args)
        case self.class.tableless_options[:database]
        when :pretend_success
          true
        when :fail_fast
          raise NoDatabase.new("Can't #create a Tableless object")
        end
      end

      def create_record(*args)
        case self.class.tableless_options[:database]
        when :pretend_success
          true
        when :fail_fast
          raise NoDatabase.new("Can't #create_record a Tableless object")
        end
      end

      def update(*args)
        case self.class.tableless_options[:database]
        when :pretend_success
          true
        when :fail_fast
          raise NoDatabase.new("Can't #update a Tableless object")
        end
      end

      def update_record(*args)
        case self.class.tableless_options[:database]
        when :pretend_success
          true
        when :fail_fast
          raise NoDatabase.new("Can't #update_record a Tableless object")
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

      if ActiveRecord::VERSION::MAJOR >= 3
        def add_to_transaction
        end
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
