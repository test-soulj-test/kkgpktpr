# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::ReleaseManagers::Schedule do
  let(:schedule) { described_class.new }
  let(:version) { ReleaseTools::Version.new('11.8') }

  let(:yaml) do
    <<~YAML
      - version: '11.8'
        date: February 22nd, 2019
        manager_americas:
          - Robert Speicher
        manager_apac_emea:
          - Yorick Peterse
      - version: '11.9'
        date: March 22nd, 2019
        manager_americas:
          - Robert Speicher
        manager_apac_emea:
          - New Team Member
      - version: '11.10'
        date: January 22nd, 2020
        manager_americas:
          - Robert Speicher
        manager_apac_emea:
          - Yorick Peterse
    YAML
  end

  def stub_schedule(body)
    stub_request(:get, described_class::SCHEDULE_YAML).to_return(body: body)
  end

  before do
    # Prevent retry delay from slowing down specs
    stub_const("#{described_class}::RETRY_INTERVAL", 0)
  end

  describe '#version_for_date' do
    context 'when there are releases scheduled' do
      before do
        stub_schedule(yaml)
      end

      it 'returns the version for the date' do
        expect(schedule.version_for_date(Date.new(2019, 2, 2))).to eq(version)
      end

      it 'returns the version for the next month when the date is after the 22nd' do
        expect(schedule.version_for_date(Date.new(2019, 2, 23)))
          .to eq(ReleaseTools::Version.new('11.9'))

        expect(schedule.version_for_date(Date.new(2019, 12, 23)))
          .to eq(ReleaseTools::Version.new('11.10'))
      end

      it 'returns nil when there is no matching release' do
        expect(schedule.version_for_date(Date.new(2005, 2, 2))).to be_nil
      end
    end

    context 'when there are no releases scheduled at all' do
      it 'returns nil' do
        stub_schedule('')

        expect(schedule.version_for_date(Date.new(2019, 2, 2))).to be_nil
      end
    end
  end

  describe '#ids_for_version' do
    context 'for authorized release managers' do
      let(:member1) { double(:member, name: 'Robert Speicher', id: 1, username: 'rspeicher') }
      let(:member2) { double(:member, name: 'Yorick Peterse', id: 2, username: 'yorickpeterse') }

      it 'returns an array of usernames' do
        allow(schedule)
          .to receive(:authorized_release_managers)
          .and_return([member1, member2])

        expect(schedule.ids_for_version(version)).to eq([1, 2])
      end
    end
  end

  describe '#usernames_for_version' do
    context 'for authorized release managers' do
      let(:member1) { double(:member, name: 'Robert Speicher', id: 1, username: 'rspeicher') }
      let(:member2) { double(:member, name: 'Yorick Peterse', id: 2, username: 'yorickpeterse') }

      it 'returns an array of usernames' do
        allow(schedule)
          .to receive(:authorized_release_managers)
          .and_return([member1, member2])

        expect(schedule.usernames_for_version(version)).to eq(%w(rspeicher yorickpeterse))
      end
    end
  end

  describe '#authorized_release_managers' do
    let(:version) { ReleaseTools::Version.new('11.9') }
    let(:release_managers_fixture) { File.expand_path('../../../fixtures/release_managers.yml', __dir__) }
    let(:definitions) { ReleaseTools::ReleaseManagers::Definitions.new(release_managers_fixture) }

    context 'for authorized release managers' do
      let(:member1) { double(:robert, name: 'Robert Speicher', id: 1, username: 'rspeicher') }
      let(:member2) { double(:new_team_member, name: 'New Team Member', id: 2, username: 'new-team-member') }

      it 'returns an array of users' do
        client = double('client')
        expect(client).to receive(:get_user).with('rspeicher').and_return(member1)
        expect(client).to receive(:get_user).with('new-team-member').and_return(member2)

        allow(ReleaseTools::ReleaseManagers::Client)
          .to receive(:new)
          .and_return(client)

        stub_schedule(yaml)

        expect(ReleaseTools::ReleaseManagers::Definitions).to receive(:new).and_return(definitions)

        expect(schedule.authorized_release_managers(version)).to contain_exactly(member1, member2)
      end
    end
  end

  describe '#group_members' do
    it 'returns a Hash mapping release manager names to their user attributes' do
      client = instance_spy(ReleaseTools::ReleaseManagers::Client)

      allow(ReleaseTools::ReleaseManagers::Client)
        .to receive(:new)
        .and_return(client)

      allow(client)
        .to receive(:members)
        .and_return([
          double(:member, name: 'Robert Speicher', id: 1, username: 'rspeicher'),
          double(:member, name: 'Yorick Peterse', id: 2, username: 'yorickpeterse')
        ])

      expect(schedule.group_members.fetch('Robert Speicher').id)
        .to eq(1)
      expect(schedule.group_members.fetch('Yorick Peterse').username)
        .to eq('yorickpeterse')
    end
  end

  describe '#release_manager_names_from_yaml' do
    context 'when no release manager data is available' do
      it 'returns an empty Array' do
        stub_schedule('')

        expect { schedule.release_manager_names_from_yaml(version) }
          .to raise_error(described_class::VersionNotFoundError)
      end
    end

    context 'when release manager data is present' do
      it 'returns the names of the release managers' do
        stub_schedule(yaml)

        expect(schedule.release_manager_names_from_yaml(version))
          .to eq(['Robert Speicher', 'Yorick Peterse'])
      end
    end
  end

  describe '#schedule_yaml' do
    context 'when the download succeeds' do
      it 'returns the release manager data' do
        stub_schedule(yaml)

        expect(schedule.schedule_yaml.length).to eq(3)
      end
    end

    context 'when the download fails' do
      it 'returns an empty Array' do
        stub_request(:any, /.*/).to_raise(Errno::ENOENT)

        expect(schedule.schedule_yaml).to be_empty
      end
    end
  end

  describe '#active_release_managers' do
    it 'return the authorized release managers for the active milestone' do
      users = double('users')

      expect(schedule)
        .to receive(:active_version)
        .and_return(version)

      expect(schedule)
        .to receive(:authorized_release_managers)
        .with(version)
        .and_return(users)

      expect(schedule.active_release_managers).to eq(users)
    end

    describe '#active_milestone' do
      it 'return the version for the active milestone' do
        today = DateTime.now

        expect(schedule)
          .to receive(:version_for_date)
                .with(today)
                .and_return(version)

        Timecop.freeze(today) do
          expect(schedule.active_version).to eq(version)
        end
      end
    end
  end
end
