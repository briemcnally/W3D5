require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
     return @columns if @columns
     cols = DBConnection.execute2(<<-SQL).first
       SELECT
         *
       FROM
         #{self.table_name}
       LIMIT
         0
     SQL
     cols.map!(&:to_sym)
     @columns = cols
   end

  def self.finalize!
    self.columns.each do |name|
    define_method(name) do
      self.attributes[name]
    end

    define_method("#{name}=") do |value|
      self.attributes[name] = value
    end
  end
end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || self.name.underscore.pluralize
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT
        #{table_name}.*
      FROM
        #{table_name}
    SQL

    parse_all(results)
  end

  def self.parse_all(results)
    results.map { |result| self.new(result) }
  end

  def self.find(id)
    results = DBConnection.execute(<<-SQL, id)
      SELECT
        #{table_name}.*
      FROM
        #{table_name}
      WHERE
        #{table_name}.id = ?
    SQL

    parse_all(results).first
  end

  def initialize(params = {})
    params.each do |key, value|
      key = key.to_sym
      if self.class.columns.include?(key)
        self.send("#{key}=", value)
      else
        raise "unknown attribute #{key}"
      end
    end
  end

  def attributes
    unless @attributes
      @attributes = {}
    else
      @attributes = @attributes
    end
  end

  def attribute_values
    self.class.columns.map { |value| self.send(value) }
  end

  def insert
    columns = self.class.columns.drop(1)
    col_names = columns.map { |col| col.to_sym }.join(", ")
    question_marks = (["?"] * columns.count).join(", ")

    DBConnection.execute(<<-SQL, *attribute_values.drop(1))
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{question_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    updated_row = self.class.columns.map { |key| "#{key} = ?" }.join(", ")

    DBConnection.execute(<<-SQL, *attribute_values, id)
      UPDATE
        #{self.class.table_name}
      SET
        #{updated_row}
      WHERE
        #{self.clas.table_name}.id = ?
    SQL
  end

  def save
    if id.nil?
      self.save
    else
      self.update
    end
  end
end
