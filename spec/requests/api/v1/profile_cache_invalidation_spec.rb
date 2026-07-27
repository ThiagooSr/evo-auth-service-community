# frozen_string_literal: true

require 'rails_helper'

# Regression spec: PUT /api/v1/profile only invalidated the /auth/validate
# cache when the avatar changed, so saving any other field (e.g.
# message_signature) kept serving a stale cached user payload for up to
# CACHE_TTL (5 min) — the frontend's hasSignature check reads that cached
# payload, so agents saw their signature icon/prefix silently disappear
# until the cache happened to expire.
RSpec.describe 'PUT /api/v1/profile — cache invalidation on any field change', type: :request do
  let(:password) { 'Test123!@' }

  let(:admin_role) { Role.find_by!(key: 'super_admin') }

  let(:user) do
    user = User.create!(
      name: 'Signature User',
      email: "profile-cache-#{SecureRandom.hex(4)}@example.com",
      password: password,
      password_confirmation: password,
      confirmed_at: Time.current
    )
    UserRole.create!(user: user, role: admin_role)
    user
  end

  let(:token) { AccessToken.create!(owner: user, name: 'profile-cache-token', scopes: 'default') }
  let(:headers) { { 'api_access_token' => token.token, 'Host' => 'localhost' } }

  it 'invalidates the cache when only message_signature changes (no avatar)' do
    expect(TokenValidationService).to receive(:invalidate_cache_for_user).with(user)

    put '/api/v1/profile', params: { profile: { message_signature: 'Nova assinatura' } }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(user.reload.message_signature).to eq('Nova assinatura')
  end

  it 'invalidates the cache when only display_name changes' do
    expect(TokenValidationService).to receive(:invalidate_cache_for_user).with(user)

    put '/api/v1/profile', params: { profile: { display_name: 'Novo nome' } }, headers: headers

    expect(response).to have_http_status(:ok)
  end

  it 'does not invalidate the cache when the update fails validation' do
    expect(TokenValidationService).not_to receive(:invalidate_cache_for_user)

    put '/api/v1/profile', params: { profile: { email: 'not-an-email' } }, headers: headers

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
