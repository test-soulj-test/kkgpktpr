# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::TimeUtil do
  around do |ex|
    Timecop.freeze(Time.new(2018, 1, 4, 8, 30, 42)) do
      ex.run
    end
  end

  describe '.timeout?' do
    let(:start_time) { Time.now.to_i - 600 }

    it 'returns false as it has not been exceeded' do
      expect(described_class.timeout?(start_time, 900)).to eq(false)
    end

    it 'returns true as it has been exceeded' do
      expect(described_class.timeout?(start_time, 9)).to eq(true)
    end
  end

  describe '.time_ago' do
    context 'when delta is less than a minute' do
      let(:time) { Time.new(2018, 1, 4, 8, 30) }

      context 'with a precision of 1' do
        it 'returns the time ago in words with a precision of 1' do
          expect(described_class.time_ago(time, precision: 1)).to eq('42 seconds ago')
        end
      end
    end

    context 'when delta is less than an hour' do
      let(:time) { Time.new(2018, 1, 4, 8) }

      it 'returns the time ago in words with a precision of 1' do
        expect(described_class.time_ago(time)).to eq('30 minutes ago')
      end

      context 'with a precision of 2' do
        it 'returns the time ago in words with a precision of 2' do
          expect(described_class.time_ago(time, precision: 2)).to eq('30 minutes, 42 seconds ago')
        end
      end
    end

    context 'when delta is less than a day' do
      let(:time) { Time.new(2018, 1, 4, 6) }

      it 'returns the time ago in words with a precision of 1' do
        expect(described_class.time_ago(time)).to eq('2 hours ago')
      end

      context 'with a precision of 2' do
        it 'returns the time ago in words with a precision of 2' do
          expect(described_class.time_ago(time, precision: 2)).to eq('2 hours, 30 minutes ago')
        end
      end

      context 'with a precision of 3' do
        it 'returns the time ago in words with a precision of 3' do
          expect(described_class.time_ago(time, precision: 3)).to eq('2 hours, 30 minutes, 42 seconds ago')
        end
      end
    end

    context 'when delta is less than a year' do
      let(:time) { Time.new(2018, 1, 2, 6) }

      it 'returns the time ago in words with a precision of 1' do
        expect(described_class.time_ago(time)).to eq('2 days ago')
      end

      context 'with a precision of 2' do
        it 'returns the time ago in words with a precision of 2' do
          expect(described_class.time_ago(time, precision: 2)).to eq('2 days, 2 hours ago')
        end
      end

      context 'with a precision of 3' do
        it 'returns the time ago in words with a precision of 3' do
          expect(described_class.time_ago(time, precision: 3)).to eq('2 days, 2 hours, 30 minutes ago')
        end
      end

      context 'with a precision of 4' do
        it 'returns the time ago in words with a precision of 4' do
          expect(described_class.time_ago(time, precision: 4)).to eq('2 days, 2 hours, 30 minutes, 42 seconds ago')
        end
      end
    end

    context 'when delta is more than a year' do
      let(:time) { Time.new(2017, 1, 3, 7, 29, 41) }

      it 'returns the time ago in words with a precision of 1' do
        expect(described_class.time_ago(time)).to eq('1 year ago')
      end

      context 'with a precision of 2' do
        it 'returns the time ago in words with a precision of 2' do
          expect(described_class.time_ago(time, precision: 2)).to eq('1 year, 1 day ago')
        end
      end

      context 'with a precision of 3' do
        it 'returns the time ago in words with a precision of 3' do
          expect(described_class.time_ago(time, precision: 3)).to eq('1 year, 1 day, 1 hour ago')
        end
      end

      context 'with a precision of 4' do
        it 'returns the time ago in words with a precision of 4' do
          expect(described_class.time_ago(time, precision: 4)).to eq('1 year, 1 day, 1 hour, 1 minute ago')
        end
      end

      context 'with a precision of 5' do
        it 'returns the time ago in words with a precision of 5' do
          expect(described_class.time_ago(time, precision: 5)).to eq('1 year, 1 day, 1 hour, 1 minute, 1 second ago')
        end
      end
    end
  end
end
