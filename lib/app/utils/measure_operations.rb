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

    def get_measure_resources_by_name(measure_name)
      @client.get "Measure?name=#{measure_name}", @client.fhir_headers(format: FHIR::Formats::ResourceFormat::RESOURCE_JSON)
    end

    def async_submit_data(params_resource)
      headers = {
        'Accept': 'application/fhir+json',
        'Content-Type': 'application/json',
        'Prefer': 'respond-async',
        'Accept-Encoding': 'gzip, deflate',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive'
      }
      LoggedRestClient.post(@instance.url + '/$import', params_resource.to_json, headers)
    end

    def cqf_ruler_client
      return @_cqf_ruler_client unless @_cqf_ruler_client.nil?

      @_cqf_ruler_client = FHIR::Client.new(Inferno::CQF_RULER)
      @_cqf_ruler_client
    end

    def get_all_library_dependent_valuesets(library, visited_ids = [])
      all_dependent_value_sets = []
      visited_ids << library.id
      # iterate over dependent libraries
      required_library_ids = get_required_library_ids(library)
      required_library_ids.each do |library_id|
        all_dependent_value_sets.concat(get_all_library_dependent_valuesets(get_library_resource(library_id), visited_ids)) unless visited_ids.include?(library_id)
      end

      all_dependent_value_sets.concat(get_valueset_urls(library)).uniq
    end

    def get_measure_resource(measure_id)
      measures_endpoint = Inferno::CQF_RULER + 'Measure'
      measure_request = cqf_ruler_client.client.get("#{measures_endpoint}/#{measure_id}")
      raise StandardError, "Could not retrieve measure #{measure_id} from CQF Ruler." if measure_request.code != 200

      FHIR::STU3::Measure.new JSON.parse(measure_request.body)
    end

    def get_library_resource(library_id)
      libraries_endpoint = Inferno::CQF_RULER + 'Library'
      library_request = cqf_ruler_client.client.get("#{libraries_endpoint}/#{library_id}")
      raise StandardError, "Could not retrieve library #{library_id} from CQF Ruler." if library_request.code != 200

      FHIR::STU3::Library.new JSON.parse(library_request.body)
    end

    def get_all_dependent_valuesets(measure_id)
      measure = get_measure_resource(measure_id)

      # The entry measure has related libraries but no data requirements, so
      # grab the main library.
      main_library_id = measure.library[0].reference.sub('Library/', '')
      main_library = get_library_resource(main_library_id)

      get_all_library_dependent_valuesets(main_library)
    end

    def get_required_library_ids(library)
      refs = library.relatedArtifact.select { |ref| ref.type == 'depends-on' }
      refs.map { |ref| ref.resource.reference.sub 'Library/', '' }
    end

    def get_valueset_urls(library)
      library.dataRequirement.lazy
        .select { |dr| !dr.codeFilter.nil? && !dr.codeFilter[0].nil? && !dr.codeFilter[0].valueSetString.nil? }
        .map { |dr| dr.codeFilter[0].valueSetString[/([0-9]+\.)+[0-9]+/] }
        .uniq
        .to_a
    end
  end
end