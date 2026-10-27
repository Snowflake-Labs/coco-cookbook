Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "conversations#new"
  post "agent_chats", to: "agent_chats#create"
end
