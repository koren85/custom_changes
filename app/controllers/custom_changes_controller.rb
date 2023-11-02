require 'csv'

class CustomChangesController < ApplicationController
  def index
    # Получите список всех статусов задачи для использования в выпадающем списке
    @issue_statuses = IssueStatus.all
    # Получите пользователей определенной группы
    group_name = Setting.plugin_custom_changes['group_name'].to_i
    @custom_field_date_id = Setting.plugin_custom_changes['custom_field_date_id'].to_i
    @custom_user_field_id = Setting.plugin_custom_changes['custom_user_field_id'].to_i
    check_subtask = Setting.plugin_custom_changes['check_subtask'].to_i
    group = Group.find_by_id(group_name) # Предполагается, что группа идентифицируется по фамилии
    @users_in_group = group&.users&.where(status: User::STATUS_ACTIVE)&.pluck(:id, :firstname, :lastname) || []

    @projects = Project.all # Получаем список всех проектов для выпадающего списка

    if params[:project_id].present?
      @selected_project = Project.find(params[:project_id])
      all_tasks = get_tasks_from_subprojects(@selected_project)
      #@selected_project
      @issues = Issue.joins("INNER JOIN custom_values AS cv1 ON cv1.customized_id = issues.id AND cv1.custom_field_id = #{@custom_field_date_id.to_s}").where("cv1.value IS NOT NULL AND cv1.value <>''")
                     .where(id: all_tasks.map(&:id))
    else
      @issues = Issue.all.joins("INNER JOIN custom_values AS cv1 ON cv1.customized_id = issues.id AND cv1.custom_field_id = #{@custom_field_date_id.to_s}").where("cv1.value IS NOT NULL AND cv1.value <>''")
    end

    # Обработайте выбранный статус задачи
    # if params[:status_filter].present? && params[:status_filter] != '0'
    #   @issues = @issues.where(status_id: params[:status_filter])
    # else
    #   @issues = @issues
    # end

    if params[:status_filter].present?
      # Если единственное значение в массиве пустое или равно "0", не применяем фильтр
      if params[:status_filter].length == 1 && (params[:status_filter].first.blank? || params[:status_filter].first == '0')
        # выход из условия, фильтр не применяется
      else
        # Применение фильтра
        @issues = @issues.where(status_id: params[:status_filter])
      end
    end

    if params[:user_id].present?
      @selected_user_id = params[:user_id]
      @issues = @issues.joins("INNER JOIN custom_values AS cv3 ON cv3.customized_id = issues.id AND cv3.custom_field_id = #{@custom_user_field_id.to_s}",).where("cv3.value = #{@selected_user_id.to_s}")
    else
      @issues = @issues
    end

    # Exclude subtasks
    @issues = @issues.where(parent_id: nil) if check_subtask == 0

=begin
    @issues = @issues.select { |issue| count_custom_field_changes(@custom_field_date_id, issue.id, params[:start_date], params[:end_date]) > 0 }
                     .sort_by { |issue| issue.project_id }
=end
    # Применяем значение из текстового поля
    @count_int = params[:count_int].to_i

    # Фильтрация задач по кастомному полю и датам
=begin
    filtered_issues = @issues.select { |issue| count_custom_field_changes(@custom_field_date_id, issue.id, params[:start_date], params[:end_date]) > @count_int }
=end

    subquery = JournalDetail.joins(:journal)
                            .where(journals: { journalized_type: 'Issue' },
                                   property: 'cf',
                                   prop_key: @custom_field_date_id.to_s)
                            .where("journals.created_on BETWEEN ? AND ?", params[:start_date], params[:end_date])
                            .group(:journalized_id)
                            .having("count(*) > ?", @count_int)
                            .select(:journalized_id)

    filtered_issues = @issues.where(id: subquery)

    # Группировка задач по значению кастомного поля с идентификатором 52
    @issues_by_project = filtered_issues.group_by { |issue| issue.project.custom_field_value(52) }

=begin
    @issues_by_project = filtered_issues.joins(:project)
                                        .joins("LEFT JOIN custom_values AS cv2 ON cv2.customized_id = projects.id AND cv2.custom_field_id = 52")
                                        .select("issues.*, cv2.value as custom_field_value")
                                        .group("cv2.value")
=end
    #         .order("issues.id ASC")

    # Сортировка задач в каждой группе по возрастанию

    @issues_by_project.each do |_custom_field_value, custom_field_issues|
      custom_field_issues.sort_by!(&:id)
    end

  end

=begin
  def export_csv
    custom_field_date_id = Setting.plugin_custom_changes['custom_field_date_id'].to_i
    issues_ids = params[:issues]
    if issues_ids.present?
      start_date = params[:start_date]
      end_date = params[:end_date]
      csv_data = CSV.generate(headers: true) do |csv|
        csv << ['Номер задачи', 'Проект', 'Тема', 'Кол-во изменений', 'Дата начала', 'Срок завершения'] # Headers of the columns

        issues_ids.each do |selected_issue|
          issue = Issue.find_by_id(selected_issue.to_i)
          csv << [issue.id, issue.project.name, issue.subject, count_custom_field_changes(custom_field_date_id, issue.id, start_date, end_date), issue.start_date, issue.due_date]
        end
      end

      send_data csv_data, filename: 'custom_changes.csv', type: 'text/csv'
    end
  end
=end

  def export_csv
    issues_by_project = JSON.parse(params[:issues])

    if issues_by_project.present?
      start_date = params[:start_date]
      end_date = params[:end_date]

      csv_data = CSV.generate(headers: true) do |csv|
        csv << ['Статистика за период с ' + start_date + ' по ' + end_date]

        csv << ['Группа', 'Номер задачи', 'Проект', 'Тема', 'Кол-во изменений', 'Дата начала', 'Срок завершения'] # Headers of the columns

        issues_by_project.each do |group, issues|
          issues.each do |issue_hash|
            project_name = Project.find(issue_hash["project_id"]).name
            custom_field_changes_count = count_custom_field_changes(
              Setting.plugin_custom_changes['custom_field_date_id'].to_i,
              issue_hash["id"],
              start_date,
              end_date
            )

            csv << [
              group,
              issue_hash["id"],
              project_name,
              issue_hash["subject"],
              custom_field_changes_count,
              issue_hash["start_date"],
              issue_hash["due_date"]
            ]
          end
        end
      end

      send_data csv_data, filename: 'custom_changes.csv', type: 'text/csv'
    else
      # Обработка ошибки: issues_by_project не является хэшем или пуст
      # Здесь можно добавить ваш код обработки ошибок
    end
  end

  private

  def get_tasks_from_subprojects(project_id)
    # Инициализируем массив для хранения задач
    tasks = []

    # Находим выбранный проект по его идентификатору
    project = Project.find_by_id(project_id)

    # Если проект не найден или не является корневым проектом, возвращаем пустой массив
    # return tasks if project.nil? || project.root?

    # Рекурсивно обходим подпроекты и собираем задачи из каждого из них
    tasks += project.issues

    # Рекурсивно обходим дочерние проекты и собираем задачи из них
    project.descendants.each do |subproject|
      tasks += subproject.issues
    end

    return tasks
  end

  def custom_changes_params
    params.permit(:project_id, :custom_field_value, :user_id)
  end

  def custom_field_changes_count(custom_field_id, issue_id)
    JournalDetail.joins(:journal)
                 .where(journals: { journalized_type: 'Issue', journalized_id: issue_id.to_s },
                        property: 'cf',
                        prop_key: custom_field_id.to_s)
                 .count
  end

  def count_custom_field_changes(custom_field_id, issue_id, start_date, end_date)
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

#@issues = @selected_project.issues.joins("INNER JOIN custom_values AS cv1 ON cv1.customized_id = issues.id AND cv1.custom_field_id = ?",@custom_field_date_id).where("cv1.value IS NOT NULL AND cv1.value <>''")

# Issue.joins("INNER JOIN custom_values AS cv1 ON cv1.customized_id = issues.id AND cv1.custom_field_id = 1").joins("INNER JOIN custom_values AS cv3 ON cv3.customized_id = issues.id AND cv3.custom_field_id = 3").where("cv1.value IS NOT NULL AND cv3.value = ?", '1')