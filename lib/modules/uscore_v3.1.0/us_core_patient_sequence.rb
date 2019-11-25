# frozen_string_literal: true

module Inferno
  module Sequence
    class USCore310PatientSequence < SequenceBase
      title 'Patient Tests'

      description 'Verify that Patient resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCP'

      requires :token, :patient_id
      conformance_supports :Patient

      def validate_resource_item(resource, property, value)
        case property

        when '_id'
          value_found = resolve_element_from_path(resource, 'id') { |value_in_resource| value.split(',').include? value_in_resource }
          assert value_found.present?, '_id on resource does not match _id requested'

        when 'birthdate'
          value_found = resolve_element_from_path(resource, 'birthDate') do |date|
            validate_date_search(value, date)
          end
          assert value_found.present?, 'birthdate on resource does not match birthdate requested'

        when 'family'
          value_found = resolve_element_from_path(resource, 'name.family') { |value_in_resource| value.split(',').include? value_in_resource }
          assert value_found.present?, 'family on resource does not match family requested'

        when 'gender'
          value_found = resolve_element_from_path(resource, 'gender') { |value_in_resource| value.split(',').include? value_in_resource }
          assert value_found.present?, 'gender on resource does not match gender requested'

        when 'given'
          value_found = resolve_element_from_path(resource, 'name.given') { |value_in_resource| value.split(',').include? value_in_resource }
          assert value_found.present?, 'given on resource does not match given requested'

        when 'identifier'
          value_found = resolve_element_from_path(resource, 'identifier.value') { |value_in_resource| value.split(',').include? value_in_resource }
          assert value_found.present?, 'identifier on resource does not match identifier requested'

        when 'name'
          value = value.downcase
          value_found = resolve_element_from_path(resource, 'name') do |name|
            name&.text&.start_with?(value) ||
              name&.family&.downcase&.include?(value) ||
              name&.given&.any? { |given| given.downcase.start_with?(value) } ||
              name&.prefix&.any? { |prefix| prefix.downcase.start_with?(value) } ||
              name&.suffix&.any? { |suffix| suffix.downcase.start_with?(value) }
          end
          assert value_found.present?, 'name on resource does not match name requested'

        end
      end

      details %(
        The #{title} Sequence tests `#{title.gsub(/\s+/, '')}` resources associated with the provided patient.
      )

      @resources_found = false

      test :unauthorized_search do
        metadata do
          id '01'
          name 'Server rejects Patient search without authorization'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html#behavior'
          description %(
          )
          versions :r4
        end

        skip_if_not_supported(:Patient, [:search])

        @client.set_no_auth
        omit 'Do not test if no bearer token set' if @instance.token.blank?

        search_params = { patient: @instance.patient_id }
        reply = get_resource_by_params(versioned_resource_class('Patient'), search_params)
        @client.set_bearer_token(@instance.token)
        assert_response_unauthorized reply
      end

      test 'Server returns expected results from Patient search by _id' do
        metadata do
          id '02'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          description %(
          )
          versions :r4
        end

        search_params = {
          '_id': @instance.patient_id
        }

        reply = get_resource_by_params(versioned_resource_class('Patient'), search_params)
        assert_response_ok(reply)
        assert_bundle_response(reply)

        resource_count = reply&.resource&.entry&.length || 0
        @resources_found = true if resource_count.positive?

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        @patient = reply&.resource&.entry&.first&.resource
        @patient_ary = fetch_all_bundled_resources(reply&.resource)
        save_resource_ids_in_bundle(versioned_resource_class('Patient'), reply)
        save_delayed_sequence_references(@patient_ary)
        validate_search_reply(versioned_resource_class('Patient'), reply, search_params)
      end

      test 'Server returns expected results from Patient search by identifier' do
        metadata do
          id '03'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          description %(
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
        assert !@patient.nil?, 'Expected valid Patient resource to be present'

        search_params = {
          'identifier': get_value_for_search_param(resolve_element_from_path(@patient_ary, 'identifier'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Patient'), search_params)
        validate_search_reply(versioned_resource_class('Patient'), reply, search_params)
        assert_response_ok(reply)
      end

      test 'Server returns expected results from Patient search by name' do
        metadata do
          id '04'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          description %(
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
        assert !@patient.nil?, 'Expected valid Patient resource to be present'

        search_params = {
          'name': get_value_for_search_param(resolve_element_from_path(@patient_ary, 'name'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Patient'), search_params)
        validate_search_reply(versioned_resource_class('Patient'), reply, search_params)
        assert_response_ok(reply)
      end

      test 'Server returns expected results from Patient search by gender+name' do
        metadata do
          id '05'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          description %(
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
        assert !@patient.nil?, 'Expected valid Patient resource to be present'

        search_params = {
          'gender': get_value_for_search_param(resolve_element_from_path(@patient_ary, 'gender')),
          'name': get_value_for_search_param(resolve_element_from_path(@patient_ary, 'name'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Patient'), search_params)
        validate_search_reply(versioned_resource_class('Patient'), reply, search_params)
        assert_response_ok(reply)
      end

      test 'Server returns expected results from Patient search by birthdate+name' do
        metadata do
          id '06'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          description %(
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
        assert !@patient.nil?, 'Expected valid Patient resource to be present'

        search_params = {
          'birthdate': get_value_for_search_param(resolve_element_from_path(@patient_ary, 'birthDate')),
          'name': get_value_for_search_param(resolve_element_from_path(@patient_ary, 'name'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Patient'), search_params)
        validate_search_reply(versioned_resource_class('Patient'), reply, search_params)
        assert_response_ok(reply)
      end

      test 'Server returns expected results from Patient search by birthdate+family' do
        metadata do
          id '07'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          optional
          description %(
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
        assert !@patient.nil?, 'Expected valid Patient resource to be present'

        search_params = {
          'birthdate': get_value_for_search_param(resolve_element_from_path(@patient_ary, 'birthDate')),
          'family': get_value_for_search_param(resolve_element_from_path(@patient_ary, 'name.family'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Patient'), search_params)
        validate_search_reply(versioned_resource_class('Patient'), reply, search_params)
        assert_response_ok(reply)
      end

      test 'Server returns expected results from Patient search by family+gender' do
        metadata do
          id '08'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          optional
          description %(
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
        assert !@patient.nil?, 'Expected valid Patient resource to be present'

        search_params = {
          'family': get_value_for_search_param(resolve_element_from_path(@patient_ary, 'name.family')),
          'gender': get_value_for_search_param(resolve_element_from_path(@patient_ary, 'gender'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Patient'), search_params)
        validate_search_reply(versioned_resource_class('Patient'), reply, search_params)
        assert_response_ok(reply)
      end

      test :read_interaction do
        metadata do
          id '09'
          name 'Patient read interaction supported'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          description %(
          )
          versions :r4
        end

        skip_if_not_supported(:Patient, [:read])
        skip 'No Patient resources could be found for this patient. Please use patients with more information.' unless @resources_found

        validate_read_reply(@patient, versioned_resource_class('Patient'))
      end

      test :vread_interaction do
        metadata do
          id '10'
          name 'Patient vread interaction supported'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          description %(
          )
          versions :r4
        end

        skip_if_not_supported(:Patient, [:vread])
        skip 'No Patient resources could be found for this patient. Please use patients with more information.' unless @resources_found

        validate_vread_reply(@patient, versioned_resource_class('Patient'))
      end

      test :history_interaction do
        metadata do
          id '11'
          name 'Patient history interaction supported'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/CapabilityStatement-us-core-server.html'
          description %(
          )
          versions :r4
        end

        skip_if_not_supported(:Patient, [:history])
        skip 'No Patient resources could be found for this patient. Please use patients with more information.' unless @resources_found

        validate_history_reply(@patient, versioned_resource_class('Patient'))
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
          '_id': @instance.patient_id
        }

        search_params['_revinclude'] = 'Provenance:target'
        reply = get_resource_by_params(versioned_resource_class('Patient'), search_params)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        provenance_results = reply&.resource&.entry&.map(&:resource)&.any? { |resource| resource.resourceType == 'Provenance' }
        assert provenance_results, 'No Provenance resources were returned from this search'
      end

      test 'Patient resources associated with Patient conform to US Core R4 profiles' do
        metadata do
          id '13'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient'
          description %(
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
        test_resources_against_profile('Patient')
      end

      test 'At least one of every must support element is provided in any Patient for this patient.' do
        metadata do
          id '14'
          link 'https://build.fhir.org/ig/HL7/US-Core-R4/general-guidance.html/#must-support'
          description %(
          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information' unless @patient_ary&.any?
        must_support_confirmed = {}
        extensions_list = {
          'Patient.extension:race': 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race',
          'Patient.extension:ethnicity': 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity',
          'Patient.extension:birthsex': 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex'
        }
        extensions_list.each do |id, url|
          @patient_ary&.each do |resource|
            must_support_confirmed[id] = true if resource.extension.any? { |extension| extension.url == url }
            break if must_support_confirmed[id]
          end
          skip_notification = "Could not find #{id} in any of the #{@patient_ary.length} provided Patient resource(s)"
          skip skip_notification unless must_support_confirmed[id]
        end

        must_support_elements = [
          'Patient.identifier',
          'Patient.identifier.system',
          'Patient.identifier.value',
          'Patient.name',
          'Patient.name.family',
          'Patient.name.given',
          'Patient.telecom',
          'Patient.telecom.system',
          'Patient.telecom.value',
          'Patient.telecom.use',
          'Patient.gender',
          'Patient.birthDate',
          'Patient.address',
          'Patient.address.line',
          'Patient.address.city',
          'Patient.address.state',
          'Patient.address.postalCode',
          'Patient.address.period',
          'Patient.communication',
          'Patient.communication.language'
        ]
        must_support_elements.each do |path|
          @patient_ary&.each do |resource|
            truncated_path = path.gsub('Patient.', '')
            must_support_confirmed[path] = true if resolve_element_from_path(resource, truncated_path).present?
            break if must_support_confirmed[path]
          end
          resource_count = @patient_ary.length

          skip "Could not find #{path} in any of the #{resource_count} provided Patient resource(s)" unless must_support_confirmed[path]
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

        skip_if_not_supported(:Patient, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        validate_reference_resolutions(@patient)
      end
    end
  end
end
