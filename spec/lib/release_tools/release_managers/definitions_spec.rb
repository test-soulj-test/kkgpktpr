# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::ReleaseManagers::Definitions do
  subject { described_class.new(fixture) }

  let(:fixture) { File.expand_path('../../../fixtures/release_managers.yml', __dir__) }

  describe 'class delegators' do
    it 'delegates .allowed?' do
      expect(described_class).to respond_to(:allowed?)
    end

    it 'delegates .sync!' do
      expect(described_class).to respond_to(:sync!)
    end
  end

  describe '#all' do
    it 'returns an array of User objects' do
      expect(subject.all)
        .to all(be_kind_of(described_class::User))
    end

    it 'is enumerable' do
      expect(subject).to respond_to(:any?)
    end
  end

  describe '#find_user' do
    it 'finds an User by the gitlab.com username' do
      user = subject.find_user('jameslopez')

      expect(user).to be_kind_of(described_class::User)
      expect(user.name).to eq('James Lopez')
    end

    it 'returns nil for unknown users' do
      expect(subject.find_user('missing-user')).to be_nil
    end

    it 'returns nil for nil users' do
      expect(subject.find_user(nil)).to be_nil
    end

    it 'finds an User by the OPS username' do
      user = subject.find_user('new-team-member-ops', instance: :ops)

      expect(user.name).to eq('New Team Member')
    end

    it 'finds an User by the dev username' do
      user = subject.find_user('new-team-member-dev', instance: :dev)

      expect(user.name).to eq('New Team Member')
    end

    it 'raises ArgumentError when the instance is unknown' do
      expect do
        subject.find_user('new-team-member-dev', instance: :another)
      end.to raise_error(ArgumentError)
    end
  end

  describe '#allowed?' do
    it 'allows a defined member, case-insensitively' do
      expect(subject).to be_allowed('RSpeicher')
    end

    it 'disallows an undefined member' do
      expect(subject).not_to be_allowed('invalid-member')
    end
  end

  describe '#reload!' do
    it 'raises `ArgumentError` if the config file is missing' do
      expect { described_class.new('foo.yml') }
        .to raise_error(ArgumentError, 'foo.yml does not exist!')
    end

    it 'raises `ArgumentError` if the config file is empty' do
      allow(YAML).to receive(:load_file).and_return({})

      expect { described_class.new('foo.yml') }
        .to raise_error(ArgumentError, 'foo.yml contains no data')
    end
  end

  describe '#sync!' do
    before do
      schedule = instance_spy(ReleaseTools::ReleaseManagers::Schedule)
      users = %w[jameslopez new-team-member rspeicher].map { |username| double('user', username: username) }

      allow(ReleaseTools::ReleaseManagers::Schedule)
        .to receive(:new)
        .and_return(schedule)

      allow(schedule)
        .to receive(:active_release_managers)
        .and_return(users)
    end

    def client_spy(client_to_spy_on)
      client_spy = spy

      %i[slack_wrapper dev production ops].each do |instance|
        method_name = "#{instance}_client"
        ret_val = if instance == client_to_spy_on
                    client_spy
                  else
                    double.as_null_object
                  end

        allow(subject).to receive(method_name).and_return(ret_val)
      end

      client_spy
    end

    it 'syncs dev usernames' do
      client = client_spy(:dev)

      subject.sync!

      expect(client).to have_received(:sync_membership)
        .with(%w[james new-team-member-dev rspeicher])
    end

    it 'syncs production usernames' do
      client = client_spy(:production)

      subject.sync!

      expect(client).to have_received(:sync_membership)
        .with(%w[jameslopez new-team-member rspeicher])
    end

    it 'syncs ops usernames' do
      client = client_spy(:ops)

      subject.sync!

      expect(client).to have_received(:sync_membership)
        .with(%w[jameslopez new-team-member-ops rspeicher])
    end

    it 'syncs slack usernames' do
      client = client_spy(:slack_wrapper)

      subject.sync!

      expect(client).to have_received(:sync_membership)
        .with(%w[U00001 U00002 U00003])
    end

    it 'returns a `SyncResult`' do
      client_spy(:production)

      expect(subject.sync!).to be_a(ReleaseTools::ReleaseManagers::SyncResult)
    end
  end

  describe described_class::User do
    describe 'initialize' do
      it 'raises ArgumentError when no `gitlab.com` value is provided' do
        expect { described_class.new('foo', bar: :baz) }
          .to raise_error(ArgumentError, /gitlab\.com/)
      end
    end
  end
end
