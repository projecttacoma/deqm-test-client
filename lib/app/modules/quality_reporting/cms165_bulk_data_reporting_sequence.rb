# frozen_string_literal: true

require_relative '../../utils/measure_operations'

module Inferno
  module Sequence
    class CMS165BulkDataReportingSequence < SequenceBase
      include MeasureOperations
      include WebUtils

      title 'CMS165 Bulk Data Reporting'

      test_id_prefix 'CMS165Bulk'

      description 'Tests measure operations for CMS165 (Controlling High Blood Pressure). <br/><br/>'\
                  'Prior to running tests, you must: <br/>'\
                  '1) POST '\
                  '<a href="/inferno/resources/quality_reporting/Bundle/cms165vs-bundle.json">the CMS165 ValueSet Bundle</a> '\
                  'to your FHIR server, and observe the status codes in the response to ensure all resources '\
                  'saved sucessfully. <br/>'\
                  '2) POST '\
                  '<a href="/inferno/resources/quality_reporting/Bundle/cms165-bundle.json">this Bundle</a> '\
                  'to your FHIR server, and observe the status codes in the response to ensure all resources '\
                  'saved sucessfully.'

      # These values are based on the content of the CMS165 bundle used for this module.
      measure_id = 'MitreTestScript-measure-exm165-FHIR3'

      test 'Bulk Data Import' do
        metadata do
          id '01'
          link 'https://hl7.org/fhir/STU3/measure-operations.html#evaluate-measure'
          desc 'Run bulk data $import operation for CMS165'
        end

        params_file_path = File.expand_path('../../../../resources/quality_reporting/Parameters/cms165-submit-data-params.json', __dir__)
        submit_data_payload = JSON.parse(File.read(params_file_path))

        # Initial async submit data call to kick off the job
        async_submit_data_response = async_submit_data(measure_id, submit_data_payload)
        assert_response_accepted(async_submit_data_response)

        # Use the content-location in the response to check the status of the import
        # Check the status on loop until the job is finished
        content_loc = async_submit_data_response.headers[:content_location]
        polling_response = get_with_retry(content_loc, 180)
        assert_response_ok(polling_response)
        # operation_outcome = FHIR::STU3.from_contents(polling_response.body)
        # assert(!operation_outcome.nil?)

        # operation_outcome.issue.each do |i|
        #   assert(i.code == 'informational')
        # end

        input_source_client = FHIR::Client.new(submit_data_payload['inputSource'])

        # Check that the submitted resources are GETable
        # patient_get_response = @client.get('Patient/bc4159a4-6ff2-4a5b-be3a-d9c4778642c2-1')
        # assert_response_ok(patient_get_response)

        # condition_get_response = @client.get('Condition/bc4159a4-6ff2-4a5b-be3a-d9c4778642c2-2')
        # assert_response_ok(condition_get_response)

        # encounter_get_response = @client.get('Encounter/bc4159a4-6ff2-4a5b-be3a-d9c4778642c2-3')
        # assert_response_ok(encounter_get_response)

        # observation_get_response = @client.get('Observation/bc4159a4-6ff2-4a5b-be3a-d9c4778642c2-4')
        # assert_response_ok(observation_get_response)
      end
    end
  end
end
