# frozen_string_literal: true

require 'rails_helper'

# Regression spec: two different UserSerializer classes exist in this app —
# the namespaced Serializers::UserSerializer (has message_signature) and a
# top-level UserSerializer module (didn't). auth_controller#login and
# TokenValidationService both call the bare `UserSerializer.full`, which Ruby
# resolves to the top-level module, not the namespaced one — so /auth/login
# and /auth/validate silently dropped message_signature from the user
# payload. The frontend's hasSignature check reads exactly that payload, so
# the signature icon/prefix disappeared on every login and on every periodic
# /auth/validate refresh, even though GET /profile (built from a hand-rolled
# hash, not either serializer) always showed it correctly — hence "it works
# right after I save my profile, then disappears again."
RSpec.describe 'message_signature reaches the client through the real auth endpoints', type: :request do
  let(:password) { 'Test123!@' }

  let(:user) do
    User.create!(
      name: 'Signature User',
      email: "auth-signature-#{SecureRandom.hex(4)}@example.com",
      password: password,
      password_confirmation: password,
      confirmed_at: Time.current,
      message_signature: 'Thiago'
    )
  end

  let(:login_headers) { { 'Host' => 'localhost' } }

  before do
    allow(Licensing::Runtime).to receive(:context).and_return(
      instance_double(Licensing::RuntimeContext, active?: true, track_message: nil)
    )
    allow(RuntimeConfig).to receive(:account).and_return(nil)
  end

  it 'includes message_signature in the POST /api/v1/auth/login response' do
    post '/api/v1/auth/login', params: { email: user.email, password: password }, headers: login_headers

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body.dig('data', 'user', 'message_signature')).to eq('Thiago')
  end

  it 'includes message_signature in the POST /api/v1/auth/validate response' do
    post '/api/v1/auth/login', params: { email: user.email, password: password }, headers: login_headers
    access_token = JSON.parse(response.body).dig('data', 'token', 'access_token')

    post '/api/v1/auth/validate', headers: login_headers.merge('Authorization' => "Bearer #{access_token}")

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body.dig('data', 'user', 'message_signature')).to eq('Thiago')
  end

  it 'the bare UserSerializer constant used by these endpoints resolves to a class that carries message_signature' do
    expect(UserSerializer.full(user)).to include(message_signature: 'Thiago')
  end
end
