require_dependency 'issue'

module CustomChanges
  # Patches Redmine's Issues dynamically.  Adds a relationship
  # Issue +belongs_to+ to qa_contact
  module IssuePatch
    def self.included(base)
      # :nodoc:
      base.extend(ClassMethods)

      base.send(:include, InstanceMethods)

      # Same as typing in the class
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development

        def custom_field_changes_count(custom_field_id, issue_id)
          JournalDetail.joins(:journal)
                       .where(journals: { journalized_type: 'Issue', journalized_id: issue_id.to_s },
                              property: 'cf',
                              prop_key: custom_field_id.to_s)
                       .count
        end

        def count_custom_field_changes_from_date_count(custom_field_id,issue_id, start_date, end_date)
          journal_details = JournalDetail.joins(:journal)
                                         .where(journals: { journalized_type: 'Issue', journalized_id: issue_id.to_s },
                                                property: 'cf',
                                                prop_key: custom_field_id.to_s)

          if start_date.present? && end_date.present?
            journal_details = journal_details.where("journals.created_on BETWEEN ? AND ?", start_date, end_date)
          end

          journal_details.count
        end
      end

    end

  end

  module ClassMethods
  end

  module InstanceMethods

  end
end


# Add module to Issue
Issue.send(:include, CustomChanges::IssuePatch)

