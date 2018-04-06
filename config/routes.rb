Rails.application.routes.draw do
  namespace :admin do
    get "health" => "health#index"
    get "stats"  => "health#stats"

    resources :messages
    root to: "messages#index"
  end

  get "config"                            => "utilities#configuration"
  get "/ElbHealthCheck"                   => "utilities#elb_health_check"
  get "unit-types"                        => "utilities#unit_types"
  get "/"                                 => "utilities#root"

  post "/messages"                        => "messages#create"
  post "/messages/bulk_update"            => "messages_api#bulk_update"
  get  "/messages/search"                 => "messages_api#search"
  get  "/messages/:id"                    => "messages_api#show"
  post "/messages/:id"                    => "messages_api#update"

  get "/runtime_settings"                    => "runtime_settings_api#show"
  post "/runtime_settings"                    => "runtime_settings_api#update"
end
