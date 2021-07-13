# frozen_string_literal: true

module SlackWebhookHelpers
  def expect_post(params)
    expect(HTTP).to receive(:post).with(webhook_url, params)
  end

  def response(code)
    double(:response, status: double(success?: code == 200))
  end
end
