# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::TraceSection do
  let(:local_time) { Time.utc(2020, 11, 18, 0, 0, 0) }

  describe '.collapse' do
    it 'collapses output in a trace section without an icon' do
      expect(described_class).to receive(:puts).with(
        "section_start:#{local_time.to_i}:hello_world[collapsed=true]\r\e[0KHello world"
      )

      expect(described_class).to receive(:puts).with(
        "section_end:#{local_time.to_i}:hello_world\r\e[0K"
      )

      Timecop.freeze(local_time) do
        described_class.collapse('Hello world') { '' }
      end
    end

    it 'collapses output in a trace section with an icon' do
      expect(described_class).to receive(:puts).with(
        "section_start:#{local_time.to_i}:hello_world[collapsed=true]\r\e[0KFOO Hello world"
      )

      expect(described_class).to receive(:puts).with(
        "section_end:#{local_time.to_i}:hello_world\r\e[0K"
      )

      Timecop.freeze(local_time) do
        described_class.collapse('Hello world', icon: 'FOO') { '' }
      end
    end

    it 're-raises errors thrown in the block' do
      expect(described_class).to receive(:puts).with(
        "section_start:#{local_time.to_i}:hello_world[collapsed=true]\r\e[0KHello world"
      )

      expect(described_class).to receive(:puts).with(
        "section_end:#{local_time.to_i}:hello_world\r\e[0K"
      )

      expect(described_class).to receive(:puts).with(/produced an error/)

      Timecop.freeze(local_time) do
        expect { described_class.collapse('Hello world') { raise 'foo' } }
          .to raise_error(StandardError, 'foo')
      end
    end

    it 'flushes STDOUT and STDERR' do
      allow(described_class).to receive(:puts)

      # We call the original method to make sure we don't mess up RSpec's output
      # in any way.
      expect($stdout).to receive(:flush).and_call_original
      expect($stderr).to receive(:flush).and_call_original
      expect(SemanticLogger).to receive(:flush).and_call_original

      Timecop.freeze(local_time) do
        described_class.collapse('Hello world') { '' }
      end
    end
  end

  describe '.section_name' do
    it 'generates a section name' do
      expect(described_class.section_name('I  like kittens'))
        .to eq('i_like_kittens')
    end
  end
end
