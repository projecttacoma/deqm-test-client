# frozen_string_literal: true

module Inferno
  module MeasureOperations
    # Run the $evaluate-measure operation for the given Measure
    #
    # measure_id - ID of the Measure to evaluate
    # params - hash of params to form a query in the GET request url
    def evaluate_measure(measure_id, params = {})
      params_string = params.empty? ? '' : "?#{params.to_query}"
      @client.get "Measure/#{measure_id}/$evaluate-measure#{params_string}", @client.fhir_headers(format: FHIR::Formats::ResourceFormat::RESOURCE_JSON)
    end

    def submit_data
      # TODO
      nil
    end

    def collect_data(measure_id, params = {})
      params_string = params.empty? ? '' : "?#{params.to_query}"
      @client.get "Measure/#{measure_id}/$collect-data#{params_string}", @client.fhir_headers(format: FHIR::Formats::ResourceFormat::RESOURCE_JSON)
    end

    def data_requirements
      # TODO
      nil
    end
  end
end
