# frozen_string_literal: true

require 'securerandom'

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

    # Run the $data-requirements operation for the given Measure
    #
    # measure_id - ID of the Measure to get data requirements for
    # params - hash of params to form a query in the GET request url
    def data_requirements(measure_id, params = {})
      params_string = params.empty? ? '' : "?#{params.to_query}"
      @client.get "Measure/#{measure_id}/$data-requirements#{params_string}", @client.fhir_headers(format: FHIR::Formats::ResourceFormat::RESOURCE_JSON)
    end

    def query(endpoint, params = {})
      params_string = params.empty? ? '' : "?#{params.to_query}"
      @client.get "#{endpoint}#{params_string}", @client.fhir_headers(format: FHIR::Formats::ResourceFormat::RESOURCE_JSON)
    end

    def create_measure_report(measure_id, period_start, period_end)
      FHIR::MeasureReport.new.from_hash(
        type: 'data-collection',
        identifier: [{
          value: SecureRandom.uuid
        }],
        measure: {
          reference: "Measure/#{measure_id}"
        },
        period: {
          start: period_start,
          end: period_end
        },
        status: 'complete'
      )
    end

    def submit_data(measure_id, patient_resources, measure_report)
      parameters = FHIR::Parameters.new
      # TODO: this should ideally be named "measureReport" from spec: https://www.hl7.org/fhir/measure-operation-submit-data.html
      measure_report_param = FHIR::Parameters::Parameter.new(name: 'measurereport')
      measure_report_param.resource = measure_report
      parameters.parameter.push(measure_report_param)

      patient_resources.each do |r|
        resource_param = FHIR::Parameters::Parameter.new(name: 'resource')
        resource_param.resource = r
        parameters.parameter.push(resource_param)
      end

      headers = {
        content_type: 'application/json'
      }

      headers.merge!(@client.additional_headers) if @client.additional_headers

      @client.post("Measure/#{measure_id}/$submit-data", parameters, headers)
    end

    def collect_data(measure_id, params = {})
      params_string = params.empty? ? '' : "?#{params.to_query}"
      @client.get "Measure/#{measure_id}/$collect-data#{params_string}", @client.fhir_headers(format: FHIR::Formats::ResourceFormat::RESOURCE_JSON)
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

      FHIR::Measure.new JSON.parse(measure_request.body)
    end

    def get_measure_evaluation(measure_id, params = {})
      measure_evaluation_endpoint = Inferno::CQF_RULER + 'Measure'
      params_string = params.empty? ? '' : "?#{params.to_query}"
      evaluation_response = cqf_ruler_client.client.get("#{measure_evaluation_endpoint}/#{measure_id}/$evaluate-measure#{params_string}")
      raise StandardError, "Could not retrieve measure_evaluation #{measure_id} from CQF Ruler." if evaluation_response.code != 200

      FHIR::MeasureReport.new JSON.parse(evaluation_response.body)
    end

    def get_data_requirements(measure_id, params = {})
      endpoint = Inferno::CQF_RULER + 'Measure'
      params_string = params.empty? ? '' : "?#{params.to_query}"
      data_requirements_response = cqf_ruler_client.client.get("#{endpoint}/#{measure_id}/$data-requirements#{params_string}")
      raise StandardError, "Could not retrieve data_requirements for measure #{measure_id} from CQF Ruler." if data_requirements_response.code != 200

      FHIR::Library.new JSON.parse(data_requirements_response.body)
    end

    def get_query(endpoint, params = {})
      endpoint = Inferno::CQF_RULER + endpoint
      params_string = params.empty? ? '' : "?#{params.to_query}"
      response = cqf_ruler_client.client.get("#{endpoint}#{params_string}")
      raise StandardError, "Could not retrieve #{endpoint} from CQF Ruler." if response.code != 200

      FHIR.from_contents(JSON.parse(response.body))
    end

    def get_library_resource(library_id)
      libraries_endpoint = Inferno::CQF_RULER + 'Library'
      library_request = cqf_ruler_client.client.get("#{libraries_endpoint}/#{library_id}")
      raise StandardError, "Could not retrieve library #{library_id} from CQF Ruler." if library_request.code != 200

      FHIR::Library.new JSON.parse(library_request.body)
    end

    def get_all_dependent_valuesets(measure_id)
      measure = get_measure_resource(measure_id)

      # The entry measure has related libraries but no data requirements, so
      # grab the main library.
      main_library_id = measure.library[0].sub('Library/', '')
      main_library = get_library_resource(main_library_id)

      get_all_library_dependent_valuesets(main_library)
    end

    def get_required_library_ids(library)
      refs = library.relatedArtifact.select { |ref| ref.type == 'depends-on' }
      refs.map { |ref| ref.resource.sub 'Library/', '' }
    end

    def get_valueset_urls(library)
      library.dataRequirement.lazy
        .select { |dr| !dr.codeFilter.nil? && !dr.codeFilter[0].nil? && !dr.codeFilter[0].valueSet.nil? }
        .map { |dr| dr.codeFilter[0].valueSet[/([0-9]+\.)+[0-9]+/] }
        .uniq
        .to_a
    end

    def get_data_requirements_queries(data_requirement)
      # hashes with { endpoint => FHIR Type, params => { queries } }
      data_requirement
        .select { |dr| dr&.codeFilter&.first&.code&.first || dr&.codeFilter&.first&.valueSet }
        .map do |dr|
          q = { 'endpoint' => dr.type, 'params' => {} }

          # prefer specific code filter first before valueSet
          if dr.codeFilter.first.code&.first
            q['params'][dr.codeFilter.first.path.to_s] = dr.codeFilter.first.code.first.code
          elsif dr.codeFilter.first.valueSet
            q['params']["#{dr.codeFilter.first.path}:in"] = dr.codeFilter.first.valueSet
          end

          q
        end
    end

    def get_data_requirements_resources(queries)
      queries
        .map do |q|
          endpoint = Inferno::CQF_RULER + q.endpoint
          params_string = q.params.empty? ? '' : "?#{q.params.to_query}"
          
          begin
            # TODO: run query through unlogged rest client
            response = cqf_ruler_client.client.get("#{endpoint}#{params_string}")
            code = response.code
          rescue RestClient::NotFound => e
            code = 404
          end
          
          # TODO: get rid of this backup call (replace with assertion) once we have a working fhir server source for valueset search
          response = cqf_ruler_client.client.get("#{endpoint}") if code != 200

          bundle = FHIR::Bundle.new JSON.parse(response.body)
          bundle.entry.map(&:resource)
        end
      .flatten.uniq{|r| r.id}
    end
  end
end
