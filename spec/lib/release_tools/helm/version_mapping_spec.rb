# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Helm::VersionMapping do
  describe '.parse' do
    context 'when the table is missing' do
      it 'raises a ParseError' do
        expect { described_class.parse('foo') }
          .to raise_error(described_class::ParseError)
      end
    end

    context 'when the table header separator is missing' do
      it 'raises a ParseError' do
        expect { described_class.parse("#{described_class::HEADER}\n") }
          .to raise_error(described_class::ParseError)
      end
    end

    context 'when a row is missing a Helm version' do
      it 'raises a ParseError' do
        input = <<~MARKDOWN
          #{described_class::HEADER}
          #{described_class::DIVIDER}
          | | 1.0.0 |
        MARKDOWN

        expect { described_class.parse(input) }
          .to raise_error(described_class::ParseError)
      end
    end

    context 'when a row is missing a GitLab version' do
      it 'raises a ParseError' do
        input = <<~MARKDOWN
          #{described_class::HEADER}
          #{described_class::DIVIDER}
          | 1.0.0 | |
        MARKDOWN

        expect { described_class.parse(input) }
          .to raise_error(described_class::ParseError)
      end
    end

    context 'when the table is valid' do
      it 'parses the table into a VersionMapping instance' do
        input = <<~MARKDOWN
          foo

          #{described_class::HEADER}
          #{described_class::DIVIDER}
          | 1.0.0 | 2.0.0 |

          bar
        MARKDOWN

        mapping = described_class.parse(input)

        expect(mapping.start).to eq(2)
        expect(mapping.stop).to eq(4)
        expect(mapping.lines).to be_frozen
        expect(mapping.lines).to eq(
          [
            'foo',
            '',
            described_class::HEADER,
            described_class::DIVIDER,
            '| 1.0.0 | 2.0.0 |',
            '',
            'bar'
          ]
        )

        expect(mapping.rows.length).to eq(1)

        expect(mapping.rows[0].helm_version)
          .to eq(ReleaseTools::Version.new('1.0.0'))

        expect(mapping.rows[0].gitlab_version)
          .to eq(ReleaseTools::Version.new('2.0.0'))
      end
    end
  end

  describe '#add' do
    context 'when the Helm version has not yet been added' do
      it 'adds a new row' do
        mapping = described_class.new(lines: [], rows: [], start: 0, stop: 0)

        mapping.add(
          ReleaseTools::Version.new('1.0.0'),
          ReleaseTools::Version.new('2.0.0')
        )

        expect(mapping.rows.length).to eq(1)

        expect(mapping.rows[0].helm_version)
          .to eq(ReleaseTools::Version.new('1.0.0'))

        expect(mapping.rows[0].gitlab_version)
          .to eq(ReleaseTools::Version.new('2.0.0'))
      end
    end

    context 'when a Helm version has already been added' do
      it 'updates the GitLab version' do
        mapping = described_class.new(lines: [], rows: [], start: 0, stop: 0)

        mapping.add(
          ReleaseTools::Version.new('1.0.0'),
          ReleaseTools::Version.new('2.0.0')
        )

        mapping.add(
          ReleaseTools::Version.new('1.0.0'),
          ReleaseTools::Version.new('5.0.0')
        )

        expect(mapping.rows.length).to eq(1)

        expect(mapping.rows[0].gitlab_version)
          .to eq(ReleaseTools::Version.new('5.0.0'))
      end
    end
  end

  describe '#to_s' do
    it 'converts the mapping back to Markdown' do
      input = <<~MARKDOWN
        foo

        #{described_class::HEADER}
        #{described_class::DIVIDER}
        | 1.0.0 | 2.0.0 |

        bar
      MARKDOWN

      output = <<~MARKDOWN
        foo

        #{described_class::HEADER}
        #{described_class::DIVIDER}
        | 2.0.0 | 3.0.0 |
        | 1.0.0 | 2.0.0 |
        | 0.1.0 | 1.0.0 |

        bar
      MARKDOWN

      mapping = described_class.parse(input)

      mapping.add(
        ReleaseTools::Version.new('0.1.0'),
        ReleaseTools::Version.new('1.0.0')
      )

      mapping.add(
        ReleaseTools::Version.new('2.0.0'),
        ReleaseTools::Version.new('3.0.0')
      )

      expect(mapping.to_s).to eq(output)
    end
  end
end
