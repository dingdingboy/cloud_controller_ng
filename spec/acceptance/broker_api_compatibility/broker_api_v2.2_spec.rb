require 'spec_helper'

describe 'Service Broker API integration' do
  describe 'v2.2' do
    before do
      VCAP::CloudController::Controller.any_instance.stub(:in_test_mode?).and_return(false)
    end

    before(:all) { setup_cc }
    after(:all) { $spec_env.reset_database_with_seeds }

    let(:broker_url) { 'broker-url' }
    let(:broker_name) { 'broker-name' }
    let(:broker_auth_username) { 'username' }
    let(:broker_auth_password) { 'password' }
    let(:broker_response_status) { 200 }

    describe 'Catalog Management' do
      describe 'fetching the catalog' do
        let(:username_pattern) { '[[:alnum:]-]+' }
        let(:password_pattern) { '[[:alnum:]-]+' }

        let(:catalog) do
          {
          services: [{
          id:          "service-guid-here",
          name:        "MySQL",
          description: "A MySQL-compatible relational database",
          bindable:    true,
          dashboard_client: {
          id:           "dash-id",
          secret:       "dash-board-confessional-ahhhhh",
          redirect_uri: "http://redirect.to.me.plz"
          },
          plans:       [{
          id:          "plan1-guid-here",
          name:        "small",
          description: "A small shared database with 100mb storage quota and 10 connections"
          }, {
          id:          "plan2-guid-here",
          name:        "large",
          description: "A large dedicated database with 10GB storage quota, 512MB of RAM, and 100 connections"
          }]
          }]
          }
        end

        context 'when create-service-broker' do
          after { delete_broker }
          before do
            setup_uaa_stubs_to_add_new_client

            stub_catalog_fetch(broker_response_status, catalog)

            post('/v2/service_brokers', {
              name:          broker_name,
              broker_url:    'http://' + broker_url,
              auth_username: broker_auth_username,
              auth_password: broker_auth_password
            }.to_json,
                 json_headers(admin_headers))
          end

          it 'handles the dashboard_client in the broker catalog' do
            expect(last_response.status).to eq(201)
          end
        end

        context 'when update-service-broker' do
          after { delete_broker }
          before do
            setup_uaa_stubs_to_add_new_client
            setup_broker(catalog)

            # stub uaa token request
            stub_request(:post, 'http://cc_service_broker_client:some-sekret@localhost:8080/uaa/oauth/token').to_return(
              status:  200,
              body:    { token_type: 'token-type', access_token: 'access-token' }.to_json,
              headers: { 'content-type' => 'application/json' })

            # stub uaa client search request
            stub_request(:get, 'http://localhost:8080/uaa/oauth/clients/dash-id').to_return(
              status:  200,
              body:    { id: 'some-id', client_id: 'dash-id' }.to_json,
              headers: { 'content-type' => 'application/json' })

            stub_catalog_fetch(broker_response_status, catalog)

            put("/v2/service_brokers/#{@broker_guid}",
              {}.to_json,
              json_headers(admin_headers))
          end

          it 'handles the dashboard_client in the broker catalog' do
            expect(last_response.status).to eq(200)
          end
        end
      end
    end
  end
end

def setup_uaa_stubs_to_add_new_client
  # stub uaa token request
  stub_request(:post, 'http://cc_service_broker_client:some-sekret@localhost:8080/uaa/oauth/token').to_return(
    status:  200,
    body:    { token_type: 'token-type', access_token: 'access-token' }.to_json,
    headers: { 'content-type' => 'application/json' })

  # stub uaa client search request
  stub_request(:get, 'http://localhost:8080/uaa/oauth/clients/dash-id').to_return(status: 404)

  # stub uaa client create request
  stub_request(:post, 'http://localhost:8080/uaa/oauth/clients').to_return(
    status:  201,
    body:    { id: 'some-id', client_id: 'dash-id' }.to_json,
    headers: { 'content-type' => 'application/json' })
end
