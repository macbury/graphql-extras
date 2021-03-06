require "support/database"

RSpec.describe GraphQL::Extras::Batch do
  class Foo < ActiveRecord::Base
  end

  class Bar < ActiveRecord::Base
    belongs_to :foo
  end

  class ResourceType < GraphQL::Schema::Object
    field :id, ID, null: false
  end

  class BarType < ResourceType
    field :foo, ResourceType, null: false
  end

  class BatchedBarType < ResourceType
    include GraphQL::Extras::Batch::Resolvers
    field :foo, ResourceType, null: false, resolve: association(:foo)
  end

  class BatchQueryType < GraphQL::Schema::Object
    field :bars, [BarType], null: false
    field :bars_batched, [BatchedBarType], null: false
    def bars; Bar.all; end
    def bars_batched; Bar.all; end
  end

  class BatchSchema < GraphQL::Schema
    query BatchQueryType
    use GraphQL::Batch
  end

  before :all do
    Database.setup do
      create_table(:foos, force: true)
      create_table(:bars, force: true) do |t|
        t.belongs_to :foo
      end
    end
  end

  before do
    5.times { Bar.create!(foo: Foo.create!) }
  end

  it "fires N+1 queries without batching" do
    query = <<~GRAPHQL
      query {
        bars {
          id
          foo { id }
        }
      }
    GRAPHQL

    count = Database.count_queries(/SELECT.*foos/i) do
      BatchSchema.execute(query)
    end

    expect(count).to eq(5)
  end

  it "fires 1 query with batching" do
    query = <<~GRAPHQL
      query {
        barsBatched {
          id
          foo { id }
        }
      }
    GRAPHQL

    count = Database.count_queries(/SELECT.*foos/i) do
      BatchSchema.execute(query)
    end

    expect(count).to eq(1)
  end
end
