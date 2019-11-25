# frozen_string_literal: true

module Inferno
  module Sequence
    class USCore310ImmunizationSequence < SequenceBase
      title 'Immunization Tests'

      description 'Verify that Immunization resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCI'

      requires :token, :patient_id
      conformance_supports :Immunization

      def validate_resource_item(resource, property, value)
        case property

        when 'patient'
          value_found = resolve_element_from_path(resource, 'patient.reference') { |reference| [value, 'Patient/' + value].include? reference }
          assert value_found.present?, 'patient on resource does not match patient requested'

        when 'status'
          value_found = resolve_element_from_path(resource, 'status') { |value_in_resource| value.split(',').include? value_in_resource }
          assert value_found.present?, 'status on resource does not match status requested'

        when 'date'
          value_found = resolve_element_from_path(resource, 'occurrenceDateTime') do |date|
            validate_date_search(value, date)
          end
          assert value_found.present?, 'date on resource does not match date requested'

        end
      end

      details %(
        The #{title} Sequence tests `#{title.gsub(/\s+/, '')}` resources associated with the provided patient.
      )

      @resources_found = false

      test :unauthorized_search do
        metadata do
          id '01'
          name 'Server rejects Immunization search without authorization'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html#behavior'
          description %(
          )
          versions :r4
        end

        skip_if_not_supported(:Immunization, [:search])

        @client.set_no_auth
        omit 'Do not test if no bearer token set' if @instance.token.blank?

        search_params = { patient: @instance.patient_id }
        reply = get_resource_by_params(versioned_resource_class('Immunization'), search_params)
        @client.set_bearer_token(@instance.token)
        assert_response_unauthorized reply
      end

      test 'Server returns expected results from Immunization search by patient' do
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

        reply = get_resource_by_params(versioned_resource_class('Immunization'), search_params)
        assert_response_ok(reply)
        assert_bundle_response(reply)

        resource_count = reply&.resource&.entry&.length || 0
        @resources_found = true if resource_count.positive?

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        @immunization = reply&.resource&.entry&.first&.resource
        @immunization_ary = fetch_all_bundled_resources(reply&.resource)
        save_resource_ids_in_bundle(versioned_resource_class('Immunization'), reply)
        save_delayed_sequence_references(@immunization_ary)
        validate_search_reply(versioned_resource_class('Immunization'), reply, search_params)
      end

      test 'Server returns expected results from Immunization search by patient+date' do
        metadata do
          id '03'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          optional
          description %(
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
        assert !@immunization.nil?, 'Expected valid Immunization resource to be present'

        search_params = {
          'patient': @instance.patient_id,
          'date': get_value_for_search_param(resolve_element_from_path(@immunization_ary, 'occurrenceDateTime'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Immunization'), search_params)
        validate_search_reply(versioned_resource_class('Immunization'), reply, search_params)
        assert_response_ok(reply)

        ['gt', 'lt', 'le'].each do |comparator|
          comparator_val = date_comparator_value(comparator, search_params[:date])
          comparator_search_params = { 'patient': search_params[:patient], 'date': comparator_val }
          reply = get_resource_by_params(versioned_resource_class('Immunization'), comparator_search_params)
          validate_search_reply(versioned_resource_class('Immunization'), reply, comparator_search_params)
          assert_response_ok(reply)
        end
      end

      test 'Server returns expected results from Immunization search by patient+status' do
        metadata do
          id '04'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          optional
          description %(
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
        assert !@immunization.nil?, 'Expected valid Immunization resource to be present'

        search_params = {
          'patient': @instance.patient_id,
          'status': get_value_for_search_param(resolve_element_from_path(@immunization_ary, 'status'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Immunization'), search_params)
        validate_search_reply(versioned_resource_class('Immunization'), reply, search_params)
        assert_response_ok(reply)
      end

      test :read_interaction do
        metadata do
          id '05'
          name 'Immunization read interaction supported'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          description %(
          )
          versions :r4
        end

        skip_if_not_supported(:Immunization, [:read])
        skip 'No Immunization resources could be found for this patient. Please use patients with more information.' unless @resources_found

        validate_read_reply(@immunization, versioned_resource_class('Immunization'))
      end

      test :vread_interaction do
        metadata do
          id '06'
          name 'Immunization vread interaction supported'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          description %(
          )
          versions :r4
        end

        skip_if_not_supported(:Immunization, [:vread])
        skip 'No Immunization resources could be found for this patient. Please use patients with more information.' unless @resources_found

        validate_vread_reply(@immunization, versioned_resource_class('Immunization'))
      end

      test :history_interaction do
        metadata do
          id '07'
          name 'Immunization history interaction supported'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          description %(
          )
          versions :r4
        end

        skip_if_not_supported(:Immunization, [:history])
        skip 'No Immunization resources could be found for this patient. Please use patients with more information.' unless @resources_found

        validate_history_reply(@immunization, versioned_resource_class('Immunization'))
      end

      test 'Server returns the appropriate resources from the following _revincludes: Provenance:target' do
        metadata do
          id '08'
          link 'https://www.hl7.org/fhir/search.html#revinclude'
          description %(
          )
          versions :r4
        end

        search_params = {
          'patient': @instance.patient_id
        }

        search_params['_revinclude'] = 'Provenance:target'
        reply = get_resource_by_params(versioned_resource_class('Immunization'), search_params)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        provenance_results = reply&.resource&.entry&.map(&:resource)&.any? { |resource| resource.resourceType == 'Provenance' }
        assert provenance_results, 'No Provenance resources were returned from this search'
      end

      test 'Immunization resources associated with Patient conform to US Core R4 profiles' do
        metadata do
          id '09'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-immunization'
          description %(
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
        test_resources_against_profile('Immunization')
      end

      test 'At least one of every must support element is provided in any Immunization for this patient.' do
        metadata do
          id '10'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/general-guidance.html/#must-support'
          description %(
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information' unless @immunization_ary&.any?
        must_support_confirmed = {}
        must_support_elements = [
          'Immunization.status',
          'Immunization.statusReason',
          'Immunization.vaccineCode',
          'Immunization.patient',
          'Immunization.occurrenceDateTime',
          'Immunization.occurrenceString',
          'Immunization.primarySource'
        ]
        must_support_elements.each do |path|
          @immunization_ary&.each do |resource|
            truncated_path = path.gsub('Immunization.', '')
            must_support_confirmed[path] = true if resolve_element_from_path(resource, truncated_path).present?
            break if must_support_confirmed[path]
          end
          resource_count = @immunization_ary.length

          skip "Could not find #{path} in any of the #{resource_count} provided Immunization resource(s)" unless must_support_confirmed[path]
        end
        @instance.save!
      end

      test 'All references can be resolved' do
        metadata do
          id '11'
          link 'https://www.hl7.org/fhir/DSTU2/references.html'
          description %(
          )
          versions :r4
        end

        skip_if_not_supported(:Immunization, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        validate_reference_resolutions(@immunization)
      end
    end
  end
end
