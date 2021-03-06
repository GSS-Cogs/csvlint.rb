# frozen_string_literal: true

require 'csvlint'
require 'colorize'
require 'json'
require 'pp'
require 'thor'

require 'active_support/inflector'

require 'builder'

module Csvlint
  class Cli < Thor
    desc 'myfile.csv OR csvlint http://example.com/myfile.csv', 'Supports validating CSV files to check their syntax and contents'

    option :dump_errors, desc: 'Pretty print error and warning objects.', type: :boolean, aliases: :d
    option :schema, banner: 'FILENAME OR URL', desc: 'Schema file', aliases: :s
    option :format, desc: 'Output format for errors: json or junit', aliases: :f
    option :werror, desc: 'Make all warnings into errors', type: :boolean, aliases: :w
    option :verbose, desc: 'Output progress', type: :boolean, aliases: :v

    def validate(source = nil)
      source = read_source(source)
      @schema = get_schema(options[:schema]) if options[:schema]
      if options.key?(:format) and options[:format] != 'json' and options[:format] != 'junit'
        return_error("Output format for errors must be json or junit.")
      end
      if options[:format] === 'junit'
        print '<?xml version="1.0" encoding="UTF-8"?>'
        print '<testsuites name="csvlint">'
      end
      if source.nil?
        valid = fetch_schema_tables(@schema, options)
      else
        valid = validate_csv(source, @schema, options[:dump_errors], options[:format], options[:werror], options[:verbose])
      end
      if options[:format] === 'junit'
        print '</testsuites>'
      end
      exit 1 unless valid
    end

    def help
      self.class.command_help(shell, :validate)
    end

    default_task :validate

    private

    def read_source(source)
      unless source.nil?
        # If the source isn't a URL, it's a file
        unless source.match?(/^http(s)?/)
          begin
            source = File.new(source)
          rescue Errno::ENOENT
            return_error "#{source} not found"
          end
        end
      end

      source
    end

    def get_schema(schema)
      begin
        schema = Csvlint::Schema.load_from_uri(schema, false)
      rescue Csvlint::Csvw::MetadataError => e
        return_error "invalid metadata: #{e.message}#{' at ' + e.path if e.path}"
      rescue OpenURI::HTTPError, Errno::ENOENT
        return_error "#{options[:schema]} not found"
      end

      if schema.class == Csvlint::Schema && schema.description == 'malformed'
        return_error 'invalid metadata: malformed JSON'
      end

      schema
    end

    def fetch_schema_tables(schema, options)
      valid = true

      unless schema.instance_of? Csvlint::Csvw::TableGroup
        return_error 'No CSV data to validate.'
      end
      schema.tables.keys.each do |source|
        unless source.match?(/^http(s)?/)
          begin
            source = source.sub('file:', '')
            source = File.new(source)
          rescue Errno::ENOENT
            return_error "#{source} not found"
          end
        end
        valid &= validate_csv(source, schema, options[:dump_errors], options[:format], options[:werror], options[:verbose])
      end

      valid
    end

    def print_error(index, error, dump, color)
      location = ''
      location += error.row.to_s if error.row
      location += "#{error.row ? ',' : ''}#{error.column}" if error.column
      if error.row || error.column
        location = "#{error.row ? 'Row' : 'Column'}: #{location}"
      end
      output_string = "#{index + 1}. "
      if error.column && @schema && @schema.class == Csvlint::Schema
        if @schema.fields[error.column - 1] != nil
          output_string += "#{@schema.fields[error.column - 1].name}: "
        end
      end
      output_string += error.type.to_s
      output_string += ". #{location}" unless location.empty?
      output_string += ". #{error.content}" if error.content

      if $stdout.tty?
        puts output_string.colorize(color)
      else
        puts output_string
      end

      pp error if dump
    end

    def print_errors(errors, dump)
      unless errors.empty?
        errors.each_with_index { |error, i| print_error(i, error, dump, :red) }
      end
    end

    def return_error(message)
      if $stdout.tty?
        puts message.colorize(:red)
      else
        puts message
      end
      exit 1
    end

    def validate_csv(source, schema, dump, format, werror, verbose)
      @error_count = 0
      start = Time.now
      validator = if !format.nil? or (verbose === false)
                    Csvlint::Validator.new(source, {}, schema)
                  else
                    Csvlint::Validator.new(source, {}, schema, lambda: report_lines)
                  end
      duration = Time.now - start

      csv = if source.class == String
              source
            elsif source.class == File
              source.path
            else
              'CSV'
            end

      if format === 'junit'
        x = Builder::XmlMarkup.new
        xml = x.testsuite(:name => csv, :failures => validator.errors.length, :time => duration) {
          validator.errors.map {
            |v| as_xml(x, v, "failure", csv)
          }
        }
        print xml
      elsif format == 'json'
        json = {
          validation: {
            state: validator.valid? ? 'valid' : 'invalid',
            errors: validator.errors.map { |v| hashify(v) },
            warnings: validator.warnings.map { |v| hashify(v) },
            info: validator.info_messages.map { |v| hashify(v) }
          }
        }.to_json
        print json
      else
        if $stdout.tty?
          puts "\r\n#{csv} is #{validator.valid? ? 'VALID'.green : 'INVALID'.red}"
        else
          puts "\r\n#{csv} is #{validator.valid? ? 'VALID' : 'INVALID'}"
        end
        print_errors(validator.errors,   dump)
        print_errors(validator.warnings, dump)
      end

      return false if werror && !validator.warnings.empty?
      validator.valid?
    end

    def as_xml(builder, validation, level, filename)
      description = """Validation #{level}: #{validation.type}
at row #{validation.row}, column #{validation.column}"""
      if validation.column && @schema && @schema.class == Csvlint::Schema
        if @schema.fields[validation.column - 1] != nil
          description += ", #{@schema.fields[validation.column - 1].name}: "
        end
      end
      if validation.content
        description += ": #{validation.content}"
      end
      builder.testcase(:name => validation.type.to_s, :classname => filename) {
        builder.tag!(level, description,
                     :message => "#{validation.type} row #{validation.row} col #{validation.column}",
                     :type => validation.type.to_s)
      }
    end

    def hashify(error)
      h = {
        type: error.type,
        category: error.category,
        row: error.row,
        col: error.column
      }

      if error.column && @schema && @schema.class == Csvlint::Schema && @schema.fields[error.column - 1] != nil
        field = @schema.fields[error.column - 1]
        h[:header] = field.name
        h[:constraints] = Hash[field.constraints.map { |k, v| [k.underscore, v] }]
      end

      h
    end

    def report_lines
      lambda do |row|
        new_errors = row.errors.count
        if new_errors > @error_count
          print '!'.red
        else
          print '.'.green
        end
        @error_count = new_errors
      end
    end
  end
end
