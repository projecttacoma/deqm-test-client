# frozen_string_literal: true

module Inferno
  module USCore310ProfileDefinitions
    class USCore310GoalSequenceDefinitions
      MUST_SUPPORTS = {
        extensions: [],
        slices: [
          {
            name: 'Goal.target.due[x]:dueDate',
            path: 'target.due',
            discriminator: {
              type: 'type',
              code: 'Date'
            }
          }
        ],
        elements: [
          {
            path: 'lifecycleStatus'
          },
          {
            path: 'description'
          },
          {
            path: 'subject'
          },
          {
            path: 'target'
          }
        ]
      }.freeze

      DELAYED_REFERENCES = [].freeze
    end
  end
end
