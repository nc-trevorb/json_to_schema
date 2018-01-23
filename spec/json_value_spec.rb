require 'spec_helper'

describe JsonValue do
  {
    JsonBool => false,
    JsonNumber => 3,
    JsonString => 'asdf',
    JsonObject => {},
    JsonArray => [],
  }.each do |json_type, value|
    context "for any type (#{json_type})" do
      describe '#to_json_schema' do
        let(:json_schema) { JsonValue.new(value).to_json_schema }

        it "should always return a HashWithIndifferentAccess with a 'type' key" do
          expect(json_schema).to be_a(HashWithIndifferentAccess)
          expect(json_schema[:type]).not_to be(nil)
          expect(json_schema[:type]).to eq(json_schema['type'])
          expect(json_schema[:type]).to eq(json_type.schema_type)
        end
      end

      describe '#schema_type' do
        let(:schema_type) { JsonValue.new(value).schema_type }

        it "should always be a string" do
          expect(schema_type).to be_a(String)
        end
      end
    end
  end

  {
    JsonBool => false,
    JsonNumber => 3,
    JsonString => 'asdf',
  }.each do |json_type, value|
    context "for value types (#{json_type})" do
      describe '#to_json_schema' do
        let(:json_schema) { JsonValue.new(value).to_json_schema }

        it "should not have any other properties" do
          expect(json_schema.keys).to eq(['type'])
        end
      end

      describe '#paths' do
        let(:prefix) { 'prefix' }
        let(:paths) { JsonValue.new(value).paths(prefix) }

        it "should be a single path with the prefix" do
          expect(paths.length).to eq(1)
          expect(paths.first).to eq("#{prefix}:#{json_type.schema_type}")
        end
      end
    end
  end

  context "for JsonArray types" do
    describe '#to_json_schema' do
      let(:json_schema) { JsonValue.new([1,2,3]).to_json_schema }

      it "should have items" do
        expect(json_schema[:items]).not_to be(nil)
      end

      it "should get the schemas of elements in the array" do
        expect(json_schema[:items]).to include({ type: JsonNumber.schema_type })
      end
    end

    describe '#paths' do
      [
        [1,2,3],
        ['asdf'],
      ].each do |value|
        context "nested primitives (#{value})" do
          let(:json_value) { JsonValue.new(value) }

          it "should use square brackets" do
            paths = json_value.paths('prefix')
            type = JsonValue.new(value.first).schema_type

            expect(paths).to include("prefix[]:#{type}")
          end
        end
      end

      [
        [[{ a: 1 }], 'number'],
        [[{ a: [{ b: 'asdf' }] }], 'string'],
      ].each do |value, type|
        context "nested objects (#{value})" do
          let(:json_value) { JsonValue.new(value) }

          it "should use square brackets" do
            path = json_value.paths('prefix').first

            expect(path.start_with?("prefix[]/a")).to be(true)
            expect(path.end_with?(":#{type}")).to be(true)
          end
        end
      end
    end
  end

  context "for JsonObject types" do
    describe '#to_json_schema' do
      let(:json_schema) { JsonValue.new({ a: 1 }).to_json_schema }

      it "should have properties" do
        nested_schema = json_schema[:properties][:a]

        expect(nested_schema[:type]).to eq(JsonNumber.schema_type)
      end

      it "should build nested properties" do
        json_schema = JsonValue.new({ a: { b: 'hi' }}).to_json_schema
        nested_schema = json_schema[:properties][:a]
        deep_nested_schema = nested_schema[:properties][:b]

        expect(nested_schema[:type]).to eq(JsonObject.schema_type)
        expect(deep_nested_schema[:type]).to eq(JsonString.schema_type)
      end
    end


    describe '#paths' do
      [
        [{ a: 1 }, ["prefix/a:number"]],
        [{ a: 1, b: 'asdf' }, ["prefix/a:number", "prefix/b:string"]],
        [{ a: { b: 'asdf' } }, ["prefix/a/b:string"]],
        [{ a: [{ b: [1, 'asdf'] }] }, ["prefix/a[]/b[]:string"]],
      ].each do |value, expected_paths|
        it "should list every path" do
          json_value = JsonValue.new(value)
          paths = json_value.paths('prefix')

          expected_paths.each do |path|
            expect(paths).to include(path)
          end
        end
      end
    end
  end

  describe "creation" do
    it "should recurse into objects to create more JsonValues" do
      arg = { a: 'asdf' }.with_indifferent_access
      expect(JsonValue.new(arg).value.values.first).to be_a(JsonValue)
    end
  end
end
