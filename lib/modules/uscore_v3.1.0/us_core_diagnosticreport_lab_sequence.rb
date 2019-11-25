# frozen_string_literal: true

module Inferno
  module Sequence
    class USCore310DiagnosticreportLabSequence < SequenceBase
      title 'DiagnosticReport for Laboratory Results Reporting Tests'

      description 'Verify that DiagnosticReport resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCDRLRR'

      requires :token, :patient_id
      conformance_supports :DiagnosticReport

      def validate_resource_item(resource, property, value)
        case property

        when 'status'
          value_found = can_resolve_path(resource, 'status') { |value_in_resource| value_in_resource == value }
          assert value_found, 'status on resource does not match status requested'

        when 'patient'
          value_found = can_resolve_path(resource, 'subject.reference') { |reference| [value, 'Patient/' + value].include? reference }
          assert value_found, 'patient on resource does not match patient requested'

        when 'category'
          value_found = can_resolve_path(resource, 'category.coding.code') { |value_in_resource| value_in_resource == value }
          assert value_found, 'category on resource does not match category requested'

        when 'code'
          value_found = can_resolve_path(resource, 'code.coding.code') { |value_in_resource| value_in_resource == value }
          assert value_found, 'code on resource does not match code requested'

        when 'date'
          value_found = can_resolve_path(resource, 'effectiveDateTime') do |date|
            validate_date_search(value, date)
          end
          assert value_found, 'date on resource does not match date requested'

        end
      end

      details %(
        The #{title} Sequence tests `#{title.gsub(/\s+/, '')}` resources associated with the provided patient.
      )

      @resources_found = false

      test :unauthorized_search do
        metadata do
          id '01'
          name 'Server rejects DiagnosticReport search without authorization'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html#behavior'
          description %(
          )
          versions :r4
        end

        skip_if_not_supported(:DiagnosticReport, [:search])

        @client.set_no_auth
        omit 'Do not test if no bearer token set' if @instance.token.blank?

        search_params = { patient: @instance.patient_id }
        reply = get_resource_by_params(versioned_resource_class('DiagnosticReport'), search_params)
        @client.set_bearer_token(@instance.token)
        assert_response_unauthorized reply
      end

      test 'Server returns expected results from DiagnosticReport search by patient' do
        metadata do
          id '02'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          description %(
          )
          versions :r4
        end

        search_params = {
          'patient': @instance.patient_id
        }

        reply = get_resource_by_params(versioned_resource_class('DiagnosticReport'), search_params)
        assert_response_ok(reply)
        assert_bundle_response(reply)

        resource_count = reply&.resource&.entry&.length || 0
        @resources_found = true if resource_count.positive?

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        @diagnostic_report = reply&.resource&.entry&.first&.resource
        @diagnostic_report_ary = fetch_all_bundled_resources(reply&.resource)
        save_resource_ids_in_bundle(versioned_resource_class('DiagnosticReport'), reply, Inferno::ValidationUtil::US_CORE_R4_URIS[:diagnostic_report_lab])
        save_delayed_sequence_references(@diagnostic_report_ary)
        validate_search_reply(versioned_resource_class('DiagnosticReport'), reply, search_params)
      end

      test 'Server returns expected results from DiagnosticReport search by patient+code' do
        metadata do
          id '03'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          description %(
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
        assert !@diagnostic_report.nil?, 'Expected valid DiagnosticReport resource to be present'

        search_params = {
          'patient': @instance.patient_id,
          'code': get_value_for_search_param(resolve_element_from_path(@diagnostic_report_ary, 'code'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('DiagnosticReport'), search_params)
        validate_search_reply(versioned_resource_class('DiagnosticReport'), reply, search_params)
        assert_response_ok(reply)
      end

      test 'Server returns expected results from DiagnosticReport search by patient+category+date' do
        metadata do
          id '04'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          description %(
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
        assert !@diagnostic_report.nil?, 'Expected valid DiagnosticReport resource to be present'

        search_params = {
          'patient': @instance.patient_id,
          'category': get_value_for_search_param(resolve_element_from_path(@diagnostic_report_ary, 'category')),
          'date': get_value_for_search_param(resolve_element_from_path(@diagnostic_report_ary, 'effectiveDateTime'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('DiagnosticReport'), search_params)
        validate_search_reply(versioned_resource_class('DiagnosticReport'), reply, search_params)
        assert_response_ok(reply)

        ['gt', 'lt', 'le', 'ge'].each do |comparator|
          comparator_val = date_comparator_value(comparator, search_params[:date])
          comparator_search_params = { 'patient': search_params[:patient], 'category': search_params[:category], 'date': comparator_val }
          reply = get_resource_by_params(versioned_resource_class('DiagnosticReport'), comparator_search_params)
          validate_search_reply(versioned_resource_class('DiagnosticReport'), reply, comparator_search_params)
          assert_response_ok(reply)
        end
      end

      test 'Server returns expected results from DiagnosticReport search by patient+category' do
        metadata do
          id '05'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          description %(
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
        assert !@diagnostic_report.nil?, 'Expected valid DiagnosticReport resource to be present'

        search_params = {
          'patient': @instance.patient_id,
          'category': 'LAB'
        }

        reply = get_resource_by_params(versioned_resource_class('DiagnosticReport'), search_params)
        validate_search_reply(versioned_resource_class('DiagnosticReport'), reply, search_params)
        assert_response_ok(reply)
      end

      test 'Server returns expected results from DiagnosticReport search by patient+status' do
        metadata do
          id '06'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          optional
          description %(
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
        assert !@diagnostic_report.nil?, 'Expected valid DiagnosticReport resource to be present'

        search_params = {
          'patient': @instance.patient_id,
          'status': get_value_for_search_param(resolve_element_from_path(@diagnostic_report_ary, 'status'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('DiagnosticReport'), search_params)
        validate_search_reply(versioned_resource_class('DiagnosticReport'), reply, search_params)
        assert_response_ok(reply)
      end

      test 'Server returns expected results from DiagnosticReport search by patient+code+date' do
        metadata do
          id '07'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          optional
          description %(
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
        assert !@diagnostic_report.nil?, 'Expected valid DiagnosticReport resource to be present'

        search_params = {
          'patient': @instance.patient_id,
          'code': get_value_for_search_param(resolve_element_from_path(@diagnostic_report_ary, 'code')),
          'date': get_value_for_search_param(resolve_element_from_path(@diagnostic_report_ary, 'effectiveDateTime'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('DiagnosticReport'), search_params)
        validate_search_reply(versioned_resource_class('DiagnosticReport'), reply, search_params)
        assert_response_ok(reply)

        ['gt', 'lt', 'le', 'ge'].each do |comparator|
          comparator_val = date_comparator_value(comparator, search_params[:date])
          comparator_search_params = { 'patient': search_params[:patient], 'code': search_params[:code], 'date': comparator_val }
          reply = get_resource_by_params(versioned_resource_class('DiagnosticReport'), comparator_search_params)
          validate_search_reply(versioned_resource_class('DiagnosticReport'), reply, comparator_search_params)
          assert_response_ok(reply)
        end
      end

      test :create_interaction do
        metadata do
          id '08'
          name 'DiagnosticReport create interaction supported'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          description %(
          )
          versions :r4
        end

        skip_if_not_supported(:DiagnosticReport, [:create])
        skip 'No DiagnosticReport resources could be found for this patient. Please use patients with more information.' unless @resources_found

        validate_create_reply(@diagnostic_report, versioned_resource_class('DiagnosticReport'))
      end

      test :read_interaction do
        metadata do
          id '09'
          name 'DiagnosticReport read interaction supported'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          description %(
          )
          versions :r4
        end

        skip_if_not_supported(:DiagnosticReport, [:read])
        skip 'No DiagnosticReport resources could be found for this patient. Please use patients with more information.' unless @resources_found

        validate_read_reply(@diagnostic_report, versioned_resource_class('DiagnosticReport'))
      end

      test :vread_interaction do
        metadata do
          id '10'
          name 'DiagnosticReport vread interaction supported'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          description %(
          )
          versions :r4
        end

        skip_if_not_supported(:DiagnosticReport, [:vread])
        skip 'No DiagnosticReport resources could be found for this patient. Please use patients with more information.' unless @resources_found

        validate_vread_reply(@diagnostic_report, versioned_resource_class('DiagnosticReport'))
      end

      test :history_interaction do
        metadata do
          id '11'
          name 'DiagnosticReport history interaction supported'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          description %(
          )
          versions :r4
        end

        skip_if_not_supported(:DiagnosticReport, [:history])
        skip 'No DiagnosticReport resources could be found for this patient. Please use patients with more information.' unless @resources_found

        validate_history_reply(@diagnostic_report, versioned_resource_class('DiagnosticReport'))
      end

      test 'Server returns the appropriate resources from the following _revincludes: Provenance:target' do
        metadata do
          id '12'
          link 'https://www.hl7.org/fhir/search.html#revinclude'
          description %(
          )
          versions :r4
        end

        search_params = {
          'patient': @instance.patient_id
        }

        search_params['_revinclude'] = 'Provenance:target'
        reply = get_resource_by_params(versioned_resource_class('DiagnosticReport'), search_params)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        provenance_results = reply&.resource&.entry&.map(&:resource)&.any? { |resource| resource.resourceType == 'Provenance' }
        assert provenance_results, 'No Provenance resources were returned from this search'
      end

      test 'DiagnosticReport resources associated with Patient conform to US Core R4 profiles' do
        metadata do
          id '13'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-diagnosticreport-lab'
          description %(
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
        test_resources_against_profile('DiagnosticReport', Inferno::ValidationUtil::US_CORE_R4_URIS[:diagnostic_report_lab])
      end

      test 'At least one of every must support element is provided in any DiagnosticReport for this patient.' do
        metadata do
          id '14'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/general-guidance.html/#must-support'
          description %(
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information' unless @diagnostic_report_ary&.any?
        must_support_confirmed = {}
        must_support_elements = [
          'DiagnosticReport.status',
          'DiagnosticReport.category',
          'DiagnosticReport.category',
          'DiagnosticReport.code',
          'DiagnosticReport.subject',
          'DiagnosticReport.effectiveDateTime',
          'DiagnosticReport.effectivePeriod',
          'DiagnosticReport.issued',
          'DiagnosticReport.performer',
          'DiagnosticReport.result'
        ]
        must_support_elements.each do |path|
          @diagnostic_report_ary&.each do |resource|
            truncated_path = path.gsub('DiagnosticReport.', '')
            must_support_confirmed[path] = true if can_resolve_path(resource, truncated_path)
            break if must_support_confirmed[path]
          end
          resource_count = @diagnostic_report_ary.length

          skip "Could not find #{path} in any of the #{resource_count} provided DiagnosticReport resource(s)" unless must_support_confirmed[path]
        end
        @instance.save!
      end

      test 'All references can be resolved' do
        metadata do
          id '15'
          link 'https://www.hl7.org/fhir/DSTU2/references.html'
          description %(
          )
          versions :r4
        end

        skip_if_not_supported(:DiagnosticReport, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        validate_reference_resolutions(@diagnostic_report)
      end
    end
  end
end
