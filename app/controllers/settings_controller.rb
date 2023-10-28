class CustomChanges::SettingsController < ApplicationController
  layout 'admin'
  before_action :require_admin

  def show
    @settings = Setting.custom_changes
  end

  def update
    Setting.custom_changes = params[:settings]
    redirect_to settings_custom_changes_path, notice: l(:notice_successful_update)
  end
end
