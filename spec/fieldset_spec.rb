require_relative './spec_helper'

require 'norikra/fieldset'

require 'json'
require 'digest'

describe Norikra::FieldSet do
  describe 'can be initialized with both of Hash parameter and String' do
    it 'accepts String as type' do
      set = Norikra::FieldSet.new({'x' => 'string', 'y' => 'long'})
      expect(set.fields['x'].type).to eql('string')
      expect(set.fields['y'].type).to eql('integer')
    end

    it 'sets optional specification nil as defaults' do
      set = Norikra::FieldSet.new({'x' => 'string', 'y' => 'long'})
      expect(set.fields['x'].optional).to be_nil
      expect(set.fields['y'].optional).to be_nil
    end

    it 'accepts second argument as optional specification' do
      set = Norikra::FieldSet.new({'x' => 'string', 'y' => 'long'}, false)
      expect(set.fields['x'].optional?).to be_falsy
      expect(set.fields['y'].optional?).to be_falsy

      set = Norikra::FieldSet.new({'x' => 'string', 'y' => 'long'}, true)
      expect(set.fields['x'].optional?).to be_truthy
      expect(set.fields['y'].optional?).to be_truthy
    end

    it 'sets summary as comma-separated labeled field-type string with sorted field order' do
      set = Norikra::FieldSet.new({'x' => 'string', 'y' => 'long'})
      expect(set.summary).to eql('x:string,y:integer')

      set = Norikra::FieldSet.new({'x' => 'string', 'y' => 'long', 'a' => 'Boolean'})
      expect(set.summary).to eql('a:boolean,x:string,y:integer')
    end

    it 'can set optional/nullable options for each fields' do
      set = Norikra::FieldSet.new({
          'x' => {type: 'string'}, # optional: default_optional(==nil, falsy), nullable: false
          'y' => {type: 'long', optional: true, nullable: true},
        })
      expect(set.fields['x'].type).to eql('string')
      expect(set.fields['x'].optional?).to be_falsy
      expect(set.fields['x'].nullable?).to be_falsy

      expect(set.fields['y'].type).to eql('integer')
      expect(set.fields['y'].optional?).to be_truthy
      expect(set.fields['y'].nullable?).to be_truthy
    end

    it 'sets summary with nullable informations, ordered by key names' do
      set = Norikra::FieldSet.new({
          'x' => {type: 'string'}, # optional: default_optional(==nil, falsy), nullable: false
          'y' => {type: 'integer', optional: true, nullable: true},
          'z' => {type: 'boolean'}
        })
      expect(set.summary).to eql('x:string,y:integer:nullable,z:boolean')
    end
  end

  context 'initialized with some fields' do
    set = Norikra::FieldSet.new({'x' => 'string', 'y' => 'long', 'a' => 'Boolean'})
    set2 = Norikra::FieldSet.new({'a' => 'string', 'b' => 'int', 'c' => 'float', 'd' => 'bool', 'e' => 'integer'})
    set3 = Norikra::FieldSet.new({
        'a' => 'string', 'b' => 'int', 'c' => 'float',
        'd' => {type:'bool', optional: true, nullable: true},
        'e' => {type:'long', optional: true, nullable: false}
      })
    set4 = Norikra::FieldSet.new({
        'a' => 'string', 'b' => 'int', 'c' => 'float',
        'd' => {type:'bool', optional: true, nullable: true},
        'e' => {type:'long', optional: true, nullable: true}
      })

    q_set1 = Norikra::FieldSet.new({'x' => 'string', 'y' => 'long'}, nil, 0, ['set1', 'g1'])
    q_set2 = Norikra::FieldSet.new({'x' => 'string', 'y' => 'long'}, nil, 0, ['set2', nil])
    q_set3 = Norikra::FieldSet.new({'x' => 'string', 'y' => 'long'}, nil, 0, ['set3', nil])

    describe '#dup' do
      it 'make duplicated object with different internal instance' do
        x = set.dup
        expect(x.fields.object_id).not_to eql(set.fields.object_id)
        expect(x.fields).to eq(set.fields)
      end

      it 'make duplicated object with query name and group' do
        expect(q_set1.dup.instance_eval{ @query_unique_keys }).to eql(['set1', 'g1'])
        expect(q_set2.dup.instance_eval{ @query_unique_keys }).to eql(['set2', nil])

        expect(q_set2 == q_set3).to be_falsy

        expect(q_set1 == q_set1.dup).to be_truthy
        expect(q_set2 == q_set2.dup).to be_truthy
        expect(q_set3 == q_set3.dup).to be_truthy
      end

      it 'make duplicated object with same type/optional/nullable specifications' do
        set3d = set3.dup
        ['a', 'b', 'c', 'd', 'e'].each do |f|
          expect(set3d.fields[f].type).to eql(set3.fields[f].type)
          expect(set3d.fields[f].optional).to eql(set3.fields[f].optional)
          expect(set3d.fields[f].nullable).to eql(set3.fields[f].nullable)
        end
      end
    end

    describe '.leaves' do
      it 'raises ArgumentError for non-container values' do
        expect { Norikra::FieldSet.leaves('value') }.to raise_error(ArgumentError)
        expect { Norikra::FieldSet.leaves('') }.to raise_error(ArgumentError)
        expect { Norikra::FieldSet.leaves(1024) }.to raise_error(ArgumentError)
        expect { Norikra::FieldSet.leaves(nil) }.to raise_error(ArgumentError)
      end
      it 'returns blank array for empty container' do
        expect( Norikra::FieldSet.leaves({}) ).to eql([])
        expect( Norikra::FieldSet.leaves([]) ).to eql([])
      end

      it 'returns field access chains to all keys of 1-depth Hash container' do
        leaves = Norikra::FieldSet.leaves({'field1' => 1, 'field2' => 2})
        expect(leaves.size).to eql(2)
        expect(leaves).to eql([['field1', 1], ['field2', 2]])
      end

      it 'returns field access chains to all indexes of 1-depth Array container' do
        leaves = Norikra::FieldSet.leaves([1, 2, 3])
        expect(leaves.size).to eql(3)
        expect(leaves).to eql([[0, 1], [1, 2], [2, 3]])
      end

      it 'returns field access chains of 2-depth array' do
        leaves = Norikra::FieldSet.leaves([[0, 1, 2], 3, 4])
        expect(leaves.size).to eql(5)
        expect(leaves[0]).to eql([0, 0, 0])
        expect(leaves[1]).to eql([0, 1, 1])
        expect(leaves[2]).to eql([0, 2, 2])
        expect(leaves[3]).to eql([1, 3])
        expect(leaves[4]).to eql([2, 4])
      end

      it 'returns field access chains of deep containers' do
        leaves = Norikra::FieldSet.leaves({'f1' => [{'fz1' => 1, 'fz2' => {'fz3' => 2, 'fz4' => 3}}, 4], 'f2' => 5})
        expect(leaves.size).to eql(5)
        expect(leaves[0]).to eql(['f1', 0, 'fz1', 1])
        expect(leaves[1]).to eql(['f1', 0, 'fz2', 'fz3', 2])
        expect(leaves[2]).to eql(['f1', 0, 'fz2', 'fz4', 3])
        expect(leaves[3]).to eql(['f1', 1, 4])
        expect(leaves[4]).to eql(['f2', 5])
      end

      it 'does not return leaves with keys nil' do
        leaves = Norikra::FieldSet.leaves({'f1' => [{'fz1' => 1, nil => {'fz3' => 2, 'fz4' => 3}}, 4], nil => 5})
        expect(leaves.size).to eql(2)
        expect(leaves[0]).to eql(['f1', 0, 'fz1', 1])
        expect(leaves[1]).to eql(['f1', 1, 4])
      end

      it 'return leaves with values nil' do
        leaves = Norikra::FieldSet.leaves({'f1' => [{'fz1' => 1}, nil, 4], 'f2' => 5, 'f3' => nil})
        expect(leaves.size).to eql(5)
        expect(leaves[0]).to eql(['f1', 0, 'fz1', 1])
        expect(leaves[1]).to eql(['f1', 1, nil])
        expect(leaves[2]).to eql(['f1', 2, 4])
        expect(leaves[3]).to eql(['f2', 5])
        expect(leaves[4]).to eql(['f3', nil])
      end

      it 'does not return leaves with empty containers' do
        leaves = Norikra::FieldSet.leaves({'f1' => [{'fz1' => 1, 'fz2' => {}}, 4], 'f2' => 5, 'f3' => []})
        expect(leaves.size).to eql(3)
        expect(leaves[0]).to eql(['f1', 0, 'fz1', 1])
        expect(leaves[1]).to eql(['f1', 1, 4])
        expect(leaves[2]).to eql(['f2', 5])
      end
    end

    describe '.field_names_key' do
      it 'returns comma-separated sorted field names of argument hash' do
        expect(Norikra::FieldSet.field_names_key({'x1'=>1,'y3'=>2,'xx'=>3,'xx1'=>4,'a'=>5})).to eql('a,x1,xx,xx1,y3')
      end

      it 'returns comma-separated sorted field names of argument hash AND non-optional fields of 2nd argument fieldset instance' do
        expect(Norikra::FieldSet.field_names_key({'x1'=>1,'y3'=>2,'xx'=>3,'xx1'=>4}, set)).to eql('a,x,x1,xx,xx1,y,y3')
      end

      it 'returns only fields with defined previously in strict-mode' do
        expect(Norikra::FieldSet.field_names_key({'x'=>1,'y'=>2,'xx'=>3,'xx1'=>4}, set, true)).to eql('a,x,y')
      end

      it 'returns fields also in additional_fields in strict-mode and additional_fields' do
        expect(Norikra::FieldSet.field_names_key({'x'=>1,'y'=>2,'xx'=>3,'xx1'=>4,'xx2'=>5,'yy'=>6,'yy1'=>7}, set, true, ['xx2','yy1'])).to eql('a,x,xx2,y,yy1')
      end

      it 'returns result w/o chained field accesses not reserved (also in non-strict mode)' do
        expect(Norikra::FieldSet.field_names_key({'x'=>1,'y'=>2,'z'=>{'x1'=>1,'x2'=>2}}, set, true, [])).to eql('a,x,y')
        expect(Norikra::FieldSet.field_names_key({'x'=>1,'y'=>2,'z'=>{'x1'=>1,'x2'=>2}}, set, false, [])).to eql('a,x,y')
      end

      it 'returns result w/ reserved chained field accesses' do
        expect(Norikra::FieldSet.field_names_key({'x'=>1,'y'=>2,'z'=>{'x1'=>1,'x2'=>2}}, set, false, ['z.x2'])).to eql('a,x,y,z.x2')
        expect(Norikra::FieldSet.field_names_key({'x'=>1,'y'=>2,'z'=>{'x1'=>1,'x2'=>2}}, set, true, ['z.x1'])).to eql('a,x,y,z.x1')
      end

      it 'returns result w/ newly founded fields in non-strict mode, only for non-chained field accesses' do
        expect(Norikra::FieldSet.field_names_key({'x'=>1,'y'=>2,'z'=>{'x1'=>1,'x2'=>2},'p'=>true}, set, false, [])).to eql('a,p,x,y')
      end

      it 'returns result w/ regulared names for chained field accesses' do
        expect(Norikra::FieldSet.field_names_key({'x'=>1,'y'=>2,'z'=>['a','b','c']}, set, false, ['z.$0'])).to eql('a,x,y,z.$0')
      end
    end

    describe '#field_names_key' do
      it 'returns comma-separeted sorted field names' do
        expect(set.field_names_key).to eql('a,x,y')
      end

      it 'returns result w/o nullable fields' do
        expect(set3.field_names_key).to eql('a,b,c,e')
        expect(set4.field_names_key).to eql('a,b,c')
      end
    end

    describe '#udpate_summary' do
      it 'changes summary with current @fields' do
        x = set.dup
        x.fields = set.fields.dup

        oldsummary = x.summary

        x.fields['x'] = Norikra::Field.new('x', 'int')

        expect(x.summary).to eql(oldsummary)

        x.update_summary

        expect(x.summary).not_to eql(oldsummary)
        expect(x.summary).to eql('a:boolean,x:integer,y:integer')

        x.fields['c'] = Norikra::Field.new('c', 'string', true, true) # optional, nullable

        x.update_summary

        expect(x.summary).to eql('a:boolean,c:string:nullable,x:integer,y:integer')

        x.fields['b'] = Norikra::Field.new('b', 'float', true, false) # optional, non-nullable

        x.update_summary

        expect(x.summary).to eql('a:boolean,b:float,c:string:nullable,x:integer,y:integer')
      end
    end

    describe '#update' do
      it 'changes field definition of this instance' do
        x = set.dup
        expect(x.fields['a'].type).to eql('boolean')
        expect(x.fields['x'].type).to eql('string')

        expect(x.fields['y'].type).to eql('integer')
        expect(x.fields['y'].optional).to be_nil

        x.update([Norikra::Field.new('y', 'int'), Norikra::Field.new('a','string')], false)

        expect(x.fields['y'].type).to eql('integer')
        expect(x.fields['y'].optional).to eql(false)

        expect(x.fields['x'].type).to eql('string')
        expect(x.fields['a'].type).to eql('string')
      end

      it 'adds field definition' do
        x = set.dup
        expect(x.fields.size).to eql(3)
        x.update([Norikra::Field.new('z', 'string')], true)
        expect(x.fields.size).to eql(4)
        expect(x.summary).to eql('a:boolean,x:string,y:integer,z:string')
        x.update([Norikra::Field.new('b', 'string', true, true), Norikra::Field.new('c', 'integer', true, true)], true)
        expect(x.fields.size).to eql(6)
        expect(x.summary).to eql('a:boolean,b:string:nullable,c:integer:nullable,x:string,y:integer,z:string')
      end
    end

    describe '#nullable_diff' do
      it 'provides the list of nullable fields, missing in self' do
        q1 = Norikra::FieldSet.new({
            'a' => 'string', 'd' => {type:'string', optional: false, nullable: true},
          })
        q2 = Norikra::FieldSet.new({
            'a' => 'string', 'b' => 'int',
            'd' => {type:'string', optional: false, nullable: true},
            'e' => {type:'int', optional: false, nullable: true},
          })

        s1 = Norikra::FieldSet.new({'a' => 'string', 'b' => 'int', 'c' => 'bool'})
        expect(s1.nullable_diff(q1).map(&:name).sort).to eql(['d'])

        s2 = Norikra::FieldSet.new({'a' => 'string'})
        expect(s2.nullable_diff(q1).map(&:name).sort).to eql(['d'])

        s3 = Norikra::FieldSet.new({'a' => 'string', 'b' => 'int', 'c' => 'bool', 'd' => 'string'})
        expect(s3.nullable_diff(q2).map(&:name).sort).to eql(['e'])
      end
    end

    describe '#definition' do
      it 'returns hash instance of fieldname => esper type' do
        d = set.definition
        expect(d).to be_instance_of(Hash)
        expect(d.size).to eql(3)
        expect(d['a']).to eql('boolean')
        expect(d['x']).to eql('string')
        expect(d['y']).to eql('long')

        s = Norikra::FieldSet.new({'a' => 'string', 'b' => 'int', 'c' => 'float', 'd' => 'bool', 'e' => 'integer'})
        d = s.definition
        expect(d).to be_instance_of(Hash)
        expect(d.size).to eql(5)
        expect(d['a']).to eql('string')
        expect(d['b']).to eql('long')
        expect(d['c']).to eql('double')
        expect(d['d']).to eql('boolean')
        expect(d['e']).to eql('long')

        d = set3.definition # nullable does not have any effects
        expect(d).to be_instance_of(Hash)
        expect(d.size).to eql(5)
        expect(d['a']).to eql('string')
        expect(d['b']).to eql('long')
        expect(d['c']).to eql('double')
        expect(d['d']).to eql('boolean')
        expect(d['e']).to eql('long')
      end
    end

    describe '#subset?' do
      it 'returns true when other instance has all fields of self' do
        other = Norikra::FieldSet.new({'a' => 'boolean', 'x' => 'string'})
        expect(set.subset?(other)).to be_falsy

        other.update([Norikra::Field.new('y', 'long')], false)
        expect(set.subset?(other)).to be_truthy

        other.update([Norikra::Field.new('z', 'double')], false)
        expect(set.subset?(other)).to be_truthy
      end

      it 'returns true if other instance does not have fields marked as nullable' do
        other = Norikra::FieldSet.new({'a' => 'string', 'b' => 'int', 'c' => 'float', 'd' => 'bool', 'e' => 'int'})
        expect(set3.subset?(other)).to be_truthy
        expect(set4.subset?(other)).to be_truthy

        other = Norikra::FieldSet.new({'a' => 'string', 'b' => 'int', 'c' => 'float'})
        expect(set3.subset?(other)).to be_falsy
        expect(set4.subset?(other)).to be_truthy

        other = Norikra::FieldSet.new({'a' => 'string', 'b' => 'int', 'c' => 'float', 'd' => 'bool'})
        expect(set3.subset?(other)).to be_falsy
        expect(set4.subset?(other)).to be_truthy

        other = Norikra::FieldSet.new({'a' => 'string', 'b' => 'int', 'c' => 'float', 'e' => 'int'})
        expect(set3.subset?(other)).to be_truthy
        expect(set4.subset?(other)).to be_truthy
      end
    end

    describe '#bind' do
      it 'sets event_type_name internally, and returns self' do
        x = set.dup

        expect(x.instance_eval{ @event_type_name }).to be_nil

        expect(x.bind('TargetExample', :query)).to eql(x)

        expect(x.instance_eval{ @event_type_name }).not_to be_nil
        expect(x.instance_eval{ @event_type_name }).to match(/q_[0-9a-f]{32}/) # MD5 hexdump
      end

      it 'sets different event_type_name for different query names and groups for query fieldsets w/ same field set' do
        x = q_set1.dup
        y = q_set2.dup
        z = q_set3.dup
        x.bind('TargetExample', :query)
        y.bind('TargetExample', :query)
        z.bind('TargetExample', :query)

        expect(x.instance_eval{ @event_type_name }).not_to eql(y.instance_eval{ @event_type_name })
        expect(x.instance_eval{ @event_type_name }).not_to eql(z.instance_eval{ @event_type_name })
      end
    end

    describe '#rebind' do
      it 'returns duplicated object, but these event_type_name are same with false argument' do
        x = set.dup
        x.bind('TargetExample', :data)

        y = x.rebind(false)
        expect(y.summary).to eql(x.summary)
        expect(y.fields.values.map(&:to_hash)).to eql(x.fields.values.map(&:to_hash))
        expect(y.target).to eql(x.target)
        expect(y.level).to eql(x.level)
        expect(y.field_names_key).to eql(x.field_names_key)

        expect(y.event_type_name).to eql(x.event_type_name)
      end

      it 'returns duplicated object, and these event_type_name should be updated with true argument' do
        x = set.dup
        x.bind('TargetExample', :data)

        y = x.rebind(true)
        expect(y.summary).to eql(x.summary)
        expect(y.fields.values.map(&:to_hash)).to eql(x.fields.values.map(&:to_hash))
        expect(y.target).to eql(x.target)
        expect(y.level).to eql(x.level)
        expect(y.field_names_key).to eql(x.field_names_key)

        expect(y.event_type_name).not_to eql(x.event_type_name)
      end
    end

    describe '#event_type_name' do
      it 'returns duplicated string of @event_type_name' do
        x = set.dup
        x.bind('TargetExample', :query)
        internal = x.instance_eval{ @event_type_name }
        expect(x.event_type_name.object_id).not_to eql(internal.object_id)
        expect(x.event_type_name).to eql(internal)
      end
    end

    describe '#format' do
      it 'returns hash value with formatted fields as defined' do
        t = Norikra::FieldSet.new({'a' => 'string', 'b' => 'long', 'c' => 'boolean', 'd' => 'double'})

        d = t.format({'a'=>'hoge','b'=>'2000','c'=>'true','d'=>'3.14'})
        expect(d['a']).to be_instance_of(String)
        expect(d['a']).to eql('hoge')
        expect(d['b']).to be_instance_of(Fixnum)
        expect(d['b']).to eql(2000)
        expect(d['c']).to be_instance_of(TrueClass)
        expect(d['c']).to eql(true)
        expect(d['d']).to be_instance_of(Float)
        expect(d['d']).to eql(3.14)
      end

      it 'returns data with keys encoded for chained field accesses' do
        t = Norikra::FieldSet.new({'a' => 'string', 'b' => 'long', 'e.$0' => 'string', 'f.foo.$$0' => 'string'})

        d = t.format({'a'=>'hoge','b'=>'2000','c'=>'true','d'=>'3.14','e'=>['moris','tago'],'f'=>{'foo'=>{'0'=>'zero','1'=>'one'},'bar'=>{'0'=>'ZERO','1'=>'ONE'}}})
        expect(d.size).to eql(4)
        expect(d['a']).to be_instance_of(String)
        expect(d['a']).to eql('hoge')
        expect(d['b']).to be_instance_of(Fixnum)
        expect(d['b']).to eql(2000)
        expect(d['e$$0']).to be_instance_of(String)
        expect(d['e$$0']).to eql('moris')
        expect(d['f$foo$$$0']).to be_instance_of(String)
        expect(d['f$foo$$$0']).to eql('zero')
      end

      it 'returns nil for value field but events has nested record' do
        t = Norikra::FieldSet.new({'a' => 'string', 'b' => 'boolean', 'c' => 'long', 'd.$0' => 'double'})

        d = t.format({'a'=>{'a1'=>"1"}, 'b'=>[1,2,3], 'c'=>{'cc'=>0.01}, 'd' => [ {'value'=>0.1} ]})
        expect(d.size).to eql(4)
        expect(d['a']).to be_nil
        expect(d['b']).to be_nil
        expect(d['c']).to be_nil
        expect(d['d$$0']).to be_nil
      end
    end
  end
end
