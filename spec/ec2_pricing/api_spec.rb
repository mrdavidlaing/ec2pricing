# encoding: utf-8

require 'spec_helper'


module Ec2Pricing
  describe Api do
    include Rack::Test::Methods

    def app
      described_class
    end

    let :response_body do
      MultiJson.load(last_response.body)
    end

    before do
      ENV['AWS_PRICING_URL'] = File.expand_path('../../resources/pricing-on-demand-instances.json', __FILE__)
    end

    shared_examples_for 'a GET URI' do
      it 'responds with OK' do
        expect(last_response.status).to be(200)
      end

      it 'responds with JSON' do
        expect(last_response.headers).to include('Content-Type' => 'application/json')
      end

      it 'allows requests from all origins' do
        expect(last_response.headers).to include('Access-Control-Allow-Origin' => '*')
      end

      it 'allows only GET, HEAD and OPTIONS requests from other origins' do
        expect(last_response.headers['Access-Control-Request-Method']).to include('GET')
        expect(last_response.headers['Access-Control-Request-Method']).to include('HEAD')
        expect(last_response.headers['Access-Control-Request-Method']).to include('OPTIONS')
        expect(last_response.headers['Access-Control-Request-Method']).to_not include('POST')
        expect(last_response.headers['Access-Control-Request-Method']).to_not include('PUT')
        expect(last_response.headers['Access-Control-Request-Method']).to_not include('DELETE')
      end
    end

    describe '/api/v1/' do
      describe '/' do
        before do
          get '/api/v1/'
        end

        it_behaves_like 'a GET URI'

        it 'returns the pricing for all regions' do
          regions = response_body.map { |region| region['region'] }
          expect(regions).to include('us-east-1', 'eu-west-1', 'sa-east-1')
        end
      end

      describe '/:region' do
        before do
          get '/api/v1/us-west-1'
        end

        it_behaves_like 'a GET URI'

        it 'returns pricing for the specified region' do
          expect(response_body['region']).to eql('us-west-1')
          expect(response_body['instance_types']).to have(10).items
          expect(response_body['instance_types'].first).to have_key('pricing')
        end

        it 'responds with Not Found for regions that do not exist' do
          get '/api/v1/eu-east-3'
          expect(last_response.status).to eql(404)
        end
      end

      describe '/:region/:family.:size' do
        before do
          get '/api/v1/us-west-2/m1.xlarge'
        end

        it_behaves_like 'a GET URI'

        it 'returns pricing for the specified instance type in the specified region' do
          expect(response_body['api_name']).to eql('m1.xlarge')
          expect(response_body).to have_key('pricing')
        end

        it 'responds with Not Found when the instance type cannot be found in the region' do
          get '/api/v1/us-west-1/cc2.8xlarge'
          expect(last_response.status).to eql(404)
        end
      end
    end
  end
end