# frozen_string_literal: true

require_relative '../../app/utils/measure_operations'
require_relative '../../app/utils/bundle'

module Inferno
  module Sequence
    class SubmitDataSequence < SequenceBase
      include MeasureOperations
      include BundleParserUtil
      title 'Submit Data'

      test_id_prefix 'submit_data'

      requires :data_requirements_queries

      description 'Ensure that resources relevant to a measure can be submitted via the $submit-data operation'

      test 'Submit Data valid submission' do
        metadata do
          id '01'
          link 'https://www.hl7.org/fhir/measure-operation-submit-data.html'
          description 'Submit resources relevant to a measure, and then verify they persist on the server.'
        end

        assert(!@instance.measure_to_test.nil?, 'No measure selected. You must run the Prerequisite sequences prior to running Reporting Actions sequences.')

        measure_identifier, measure_version = @instance.measure_to_test.split('|')
        measure_resource_system = get_measure_from_test_server(measure_identifier, measure_version)

        @client.additional_headers = { 'x-api-key': @instance.api_key, 'Authorization': @instance.auth_header } if @instance.api_key && @instance.auth_header

        # TODO: How do we decide which patient we are submitting for, if applicable???

        # Call the $updateCodeSystems workaround on embedded cqf-ruler so code:in queries work
        update_code_systems

        resources = get_data_requirements_resources(@instance.data_requirements_queries)
        measure_report = create_measure_report(measure_resource_system.url, '2019-01-01', '2019-12-31')

        # Submit the data
        submit_data_response = submit_data(measure_resource_system.id, resources, measure_report)
        assert_response_ok(submit_data_response)

        resources.push(measure_report)

        # GET and assert presence of all submitted resources
        resources.each do |r|
          identifier = r.identifier&.first&.value
          assert !identifier.nil?

          # Search for resource by identifier
          search_response = @client.search(r.class, search: { parameters: { identifier: identifier } })
          assert_response_ok search_response
          search_bundle = search_response.resource

          # Expect a non-empty searchset Bundle
          assert(search_bundle.total.positive?, "Search for a #{r.resourceType} with identifier #{identifier} returned no results")
        end
      end

      test 'Submit Data single resource submission' do
        metadata do
          id '02'
          link 'https://www.hl7.org/fhir/measure-operation-submit-data.html'
          description 'Submit a single resource relevant to a measure, and then verify it persisted on the server.'
        end

        assert(!@instance.measure_to_test.nil?, 'No measure selected. You must run the Prerequisite sequences prior to running Reporting Actions sequences.')

        measure_identifier, measure_version = @instance.measure_to_test.split('|')
        measure_resource_system = get_measure_from_test_server(measure_identifier, measure_version)

        @client.additional_headers = { 'x-api-key': @instance.api_key, 'Authorization': @instance.auth_header } if @instance.api_key && @instance.auth_header

        resources = [get_data_requirements_resources(@instance.data_requirements_queries).sample]
        measure_report = create_measure_report(measure_resource_system.url, '2019-01-01', '2019-12-31')

        # Submit the data
        submit_data_response = submit_data(measure_resource_system.id, resources, measure_report)
        assert_response_ok(submit_data_response)

        resources.push(measure_report)

        # GET and assert presence of all submitted resources
        resources.each do |r|
          identifier = r.identifier&.first&.value
          assert !identifier.nil?

          # Search for resource by identifier
          search_response = @client.search(r.class, search: { parameters: { identifier: identifier } })
          assert_response_ok search_response
          search_bundle = search_response.resource

          # Expect a non-empty searchset Bundle
          assert(search_bundle.total.positive?, "Search for a #{r.resourceType} with identifier #{identifier} returned no results")
        end
      end
    end
  end
end
