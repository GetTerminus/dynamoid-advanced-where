require_relative './filter_builder'

module DynamoidAdvancedWhere
  class QueryMaterializer
    include Enumerable
    attr_accessor :query_builder


    delegate :klass, to: :query_builder
    delegate :table_name, to: :klass
    delegate :to_a, :first, to: :each

    delegate :must_scan?, to: :filter_builder

    def initialize(query_builder:)
      self.query_builder = query_builder
    end


    def all
      each.to_a
    end

    def each(&blk)
      return enum_for(:each) unless blk

      if must_scan?
        each_via_scan(&blk)
      else
        each_via_query(&blk)
      end
    end

    def each_via_query
      query = {
        table_name: table_name,
      }.merge(filter_builder.to_query_filter)

      results = client.query(query)

      if results.items
        results.items.each do |item|
          yield klass.from_database(item.symbolize_keys)
        end
      end
    end

    def each_via_scan
      query = {
        table_name: table_name
      }.merge(filter_builder.to_scan_filter)

      results = client.scan(query)

      if results.items
        results.items.each do |item|
          yield klass.from_database(item.symbolize_keys)
        end
      end
    end

    def filter_builder
      @filter_builder ||= FilterBuilder.new(
        query_builder: self.query_builder,
        klass: klass,
      )
    end

    private
    def client
      Dynamoid.adapter.client
    end
  end
end
