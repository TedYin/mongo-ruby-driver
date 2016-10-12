require 'spec_helper'

describe Mongo::ServerSelector::SecondaryPreferred do

  let(:name) { :secondary_preferred }

  include_context 'server selector'

  it_behaves_like 'a server selector mode' do
    let(:slave_ok) { true }
  end
  it_behaves_like 'a server selector with sensitive data in its options'

  it_behaves_like 'a server selector accepting tag sets'

  describe '#initialize' do

    context 'when max_staleness is provided' do

      let(:options) do
        { max_staleness: 60 }
      end

      it 'sets the max_staleness option' do
        expect(selector.max_staleness).to eq(options[:max_staleness])
      end
    end
  end

  describe '#==' do

    context 'when max staleness is the same' do

      let(:options) do
        { max_staleness: 60 }
      end

      let(:other) do
        described_class.new(options)
      end

      it 'returns true' do
        expect(selector).to eq(other)
      end
    end

    context 'when max staleness is different' do

      let(:other_options) do
        { max_staleness: 30 }
      end

      let(:other) do
        described_class.new(other_options)
      end

      it 'returns false' do
        expect(selector).not_to eq(other)
      end
    end
  end

  describe '#to_mongos' do

    context 'tag sets provided' do

      let(:tag_sets) do
        [ tag_set ]
      end

      it 'returns a read preference formatted for mongos' do
        expect(selector.to_mongos).to eq(
          { :mode => 'secondaryPreferred', :tags => tag_sets }
        )
      end
    end

    context 'tag sets not provided' do

      it 'returns nil' do
        expect(selector.to_mongos).to be_nil
      end
    end

    context 'max staleness not provided' do

      let(:expected) do
        { :mode => 'secondaryPreferred' }
      end

      it 'returns nil' do
        expect(selector.to_mongos).to be_nil
      end
    end

    context 'max staleness provided' do

      let(:max_staleness) do
        60
      end

      let(:expected) do
        { :mode => 'secondaryPreferred', maxStalenessMS: 60000 }
      end

      it 'returns a read preference formatted for mongos' do
        expect(selector.to_mongos).to eq(expected)
      end
    end
  end

  describe '#select' do

    context 'no candidates' do
      let(:candidates) { [] }

      it 'returns an empty array' do
        expect(selector.send(:select, candidates)).to be_empty
      end
    end

    context 'single primary candidates' do
      let(:candidates) { [primary] }

      it 'returns array with primary' do
        expect(selector.send(:select, candidates)).to eq([primary])
      end
    end

    context 'single secondary candidate' do
      let(:candidates) { [secondary] }

      it 'returns array with secondary' do
        expect(selector.send(:select, candidates)).to eq([secondary])
      end
    end

    context 'primary and secondary candidates' do
      let(:candidates) { [primary, secondary] }
      let(:expected) { [secondary, primary] }

      it 'returns array with secondary first, then primary' do
        expect(selector.send(:select, candidates)).to eq(expected)
      end
    end

    context 'secondary and primary candidates' do
      let(:candidates) { [secondary, primary] }
      let(:expected) { [secondary, primary] }

      it 'returns array with secondary and primary' do
        expect(selector.send(:select, candidates)).to eq(expected)
      end
    end

    context 'tag sets provided' do

      let(:tag_sets) do
        [ tag_set ]
      end

      let(:matching_primary) do
        make_server(:primary, :tags => server_tags, address: default_address)
      end

      let(:matching_secondary) do
        make_server(:secondary, :tags => server_tags, address: default_address)
      end

      context 'single candidate' do

        context 'primary' do
          let(:candidates) { [primary] }

          it 'returns array with primary' do
            expect(selector.send(:select, candidates)).to eq([primary])
          end
        end

        context 'matching_primary' do
          let(:candidates) { [matching_primary] }

          it 'returns array with matching primary' do
            expect(selector.send(:select, candidates)).to eq([matching_primary])
          end
        end

        context 'matching secondary' do
          let(:candidates) { [matching_secondary] }

          it 'returns array with matching secondary' do
            expect(selector.send(:select, candidates)).to eq([matching_secondary])
          end
        end

        context 'secondary' do
          let(:candidates) { [secondary] }

          it 'returns an empty array' do
            expect(selector.send(:select, candidates)).to be_empty
          end
        end
      end

      context 'multiple candidates' do

        context 'no matching secondaries' do
          let(:candidates) { [primary, secondary, secondary] }

          it 'returns an array with the primary' do
            expect(selector.send(:select, candidates)).to eq([primary])
          end
        end

        context 'one matching secondary' do
          let(:candidates) { [primary, matching_secondary] }

          it 'returns an array of the matching secondary, then primary' do
            expect(selector.send(:select, candidates)).to eq(
              [matching_secondary, primary]
            )
          end
        end

        context 'two matching secondaries' do
          let(:candidates) { [primary, matching_secondary, matching_secondary] }
          let(:expected) { [matching_secondary, matching_secondary, primary] }

          it 'returns an array of the matching secondaries, then primary' do
            expect(selector.send(:select, candidates)).to eq(expected)
          end
        end

        context 'one matching secondary and one matching primary' do
          let(:candidates) { [matching_primary, matching_secondary] }
          let(:expected) {[matching_secondary, matching_primary] }

          it 'returns an array of the matching secondary, then the primary' do
            expect(selector.send(:select, candidates)).to eq(expected)
          end
        end
      end
    end

    context 'high latency servers' do
      let(:far_primary) { make_server(:primary, :average_round_trip_time => 100, address: default_address) }
      let(:far_secondary) { make_server(:secondary, :average_round_trip_time => 113, address: default_address) }

      context 'single candidate' do

        context 'far primary' do
          let(:candidates) { [far_primary] }

          it 'returns array with primary' do
            expect(selector.send(:select, candidates)).to eq([far_primary])
          end
        end

        context 'far secondary' do
          let(:candidates) { [far_secondary] }

          it 'returns an array with the secondary' do
            expect(selector.send(:select, candidates)).to eq([far_secondary])
          end
        end
      end

      context 'multiple candidates' do

        context 'local primary, local secondary' do
          let(:candidates) { [primary, secondary] }

          it 'returns an array with secondary, then primary' do
            expect(selector.send(:select, candidates)).to eq([secondary, primary])
          end
        end

        context 'local primary, far secondary' do
          let(:candidates) { [primary, far_secondary] }

          it 'returns an array with the secondary, then primary' do
            expect(selector.send(:select, candidates)).to eq([far_secondary, primary])
          end
        end

        context 'local secondary' do
          let(:candidates) { [far_primary, secondary] }
          let(:expected) { [secondary, far_primary] }

          it 'returns an array with secondary, then primary' do
            expect(selector.send(:select, candidates)).to eq(expected)
          end
        end

        context 'far primary, far secondary' do
          let(:candidates) { [far_primary, far_secondary] }
          let(:expected) { [far_secondary, far_primary] }

          it 'returns an array with secondary, then primary' do
            expect(selector.send(:select, candidates)).to eq(expected)
          end
        end

        context 'two near servers, one far secondary' do

          context 'near primary, near secondary, far secondary' do
            let(:candidates) { [primary, secondary, far_secondary] }
            let(:expected) { [secondary, primary] }

            it 'returns an array with near secondary, then primary' do
              expect(selector.send(:select, candidates)).to eq(expected)
            end
          end

          context 'two near secondaries, one far primary' do
            let(:candidates) { [far_primary, secondary, secondary] }
            let(:expected) { [secondary, secondary, far_primary] }

            it 'returns an array with secondaries, then primary' do
              expect(selector.send(:select, candidates)).to eq(expected)
            end
          end
        end
      end
    end
  end
end