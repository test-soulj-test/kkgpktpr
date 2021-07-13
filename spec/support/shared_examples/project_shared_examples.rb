# frozen_string_literal: true

RSpec.shared_examples 'project .remotes' do
  it 'returns all remotes by default' do
    expect(described_class.remotes).to eq(described_class::REMOTES)
  end

  it 'returns only dev and security remotes during a security release' do
    skip 'No dev remote' unless described_class::REMOTES.key?(:dev)

    allow(ReleaseTools::SharedStatus)
      .to receive(:security_release?)
      .and_return(true)

    expect(described_class.remotes).to eq(described_class::REMOTES.slice(:dev, :security))
  end
end

RSpec.shared_examples 'project .to_s' do
  it 'returns `path` by default' do
    expect(described_class.to_s).to eq(described_class.path)
  end

  context 'with a security release' do
    before do
      allow(ReleaseTools::SharedStatus)
        .to receive(:security_release?)
        .and_return(true)
    end

    it 'returns security path' do
      skip 'No security remote' unless described_class::REMOTES.key?(:security)

      expect(described_class.to_s).to eq(described_class.security_path)
    end
  end

  context 'with a regular release' do
    it 'returns project path' do
      expect(described_class.to_s).to eq(described_class.path)
    end
  end
end

RSpec.shared_examples 'project .canonical_or_security_path' do
  it 'returns the normal path by default' do
    expect(described_class.canonical_or_security_path)
      .to eq(described_class.path)
  end

  context 'with a security release' do
    before do
      allow(ReleaseTools::SharedStatus)
        .to receive(:security_release?)
        .and_return(true)
    end

    it 'returns the security path' do
      expect(described_class.canonical_or_security_path)
        .to eq(described_class.security_path)
    end
  end
end

RSpec.shared_examples 'project .auto_deploy_path' do
  it 'always returns the project Security path' do
    expect(described_class.auto_deploy_path).to eq(described_class.security_path)
  end
end

RSpec.shared_examples 'project .security_group' do |group_when_enabled|
  it 'returns security group' do
    group_when_enabled ||= 'gitlab-org/security'
    expect(described_class.security_group).to eq group_when_enabled
  end
end

RSpec.shared_examples 'project .security_path' do |path_when_enabled|
  it 'returns security path' do
    expect(described_class.security_path).to eq path_when_enabled
  end
end
