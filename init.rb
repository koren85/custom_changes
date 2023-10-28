Dir[File.dirname(__FILE__) + '/lib/*.rb'].each { |file| require_dependency file }

Redmine::Plugin.register :custom_changes do
  name 'Redmine Custom Statistics plugin'
  author 'Chernyaev A.A.'
  description 'Статистика изменений Итоговой даты'
  version '0.0.1'
  url ''
  author_url ''
  menu :top_menu, :custom_changes, { controller: 'custom_changes', action: 'index' }, caption: 'Custom Changes'

  settings partial: 'custom_changes/settings', default: { 'custom_field_date_id' => '','custom_user_field_id' => '' ,'group_name'=> '', 'check_subtask'=>''}

end

