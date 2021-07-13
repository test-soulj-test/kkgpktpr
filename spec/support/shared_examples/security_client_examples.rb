# frozen_string_literal: true

RSpec.shared_examples 'security_client #open_security_merge_requests' do
  it 'returns the open security merge requests' do
    merge_request = double(:merge_request)
    merge_requests = double(:merge_requests, auto_paginate: [merge_request])

    allow(client)
      .to receive(:release_tools_bot)
      .and_return(double(:bot, id: 1))

    allow(client.gitlab_client)
      .to receive(:merge_requests)
      .with(
        'foo/foo',
        per_page: 100,
        state: 'opened',
        assignee_id: 1
      )
      .and_return(merge_requests)

    expect(client.open_security_merge_requests('foo/foo'))
      .to eq([merge_request])
  end
end

RSpec.shared_examples 'security_client #release_tools_bot' do
  it 'returns the release tools bot' do
    bot = double(:bot)

    allow(client.gitlab_client)
      .to receive(:users)
      .with(username: described_class::RELEASE_TOOLS_BOT_USERNAME)
      .and_return([bot])

    expect(client.release_tools_bot).to eq(bot)
  end
end

RSpec.shared_examples 'security_client #latest_merge_request_pipeline' do
  it 'returns the latest pipeline for a merge request' do
    mr1 = double(:merge_request, id: 1)
    mr2 = double(:merge_request, id: 2)
    merge_requests = double(:merge_requests, auto_paginate: [mr2, mr1])

    allow(client.gitlab_client)
      .to receive(:merge_request_pipelines)
      .with(1, 2)
      .and_return(merge_requests)

    expect(client.latest_merge_request_pipeline(1, 2)).to eq(mr2)
  end
end

RSpec.shared_examples 'security_client #method_missing' do
  it 'delegates valid methods to the internal GitLab client' do
    allow(client.gitlab_client)
      .to receive(:users)
      .with(username: 'foo')

    client.users(username: 'foo')

    expect(client.gitlab_client).to have_received(:users)
  end

  it 'raises NoMethodError when using invalid methods' do
    expect { client.kittens }.to raise_error(NoMethodError)
  end
end

RSpec.shared_examples 'security_client #respond_to?' do
  it 'returns true for an existing method' do
    expect(client.respond_to?(:users)).to eq(true)
  end

  it 'returns false for a non-existing method' do
    expect(client.respond_to?(:kittens)).to eq(false)
  end
end
