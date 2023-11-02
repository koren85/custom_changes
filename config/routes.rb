# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
=begin
get 'custom_changes', to: 'custom_changes#index'
get 'export_csv', to: 'custom_changes#export_csv', defaults: { format: 'csv' }
=end

resources :custom_changes do
  collection do
    get 'custom_changes', to: 'custom_changes#index'
    #get 'export_csv', to: 'custom_changes#export_csv', defaults: { format: 'csv' }
    post 'export_csv', to: 'custom_changes#export_csv', as: :export_csv

  end
end