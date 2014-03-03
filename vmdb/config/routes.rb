Vmdb::Application.routes.draw do
  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

namespace :api do
  resources :vm,      :defaults => { :format => 'xml'}
  resources :host,    :defaults => { :format => 'xml'}
  match "login", :to => "sessions#create", :defaults => { :format => 'xml'}
  match "logout", :to => "sessions#logout", :defaults => { :format => 'xml'}
  match 'vm/:id/poweron', :to => 'vm#poweron'
  match 'vm/:id/poweroff', :to => 'vm#poweroff'
  match 'vm/:id/shutdown', :to => 'vm#shutdown'
  match "createvms", :to => "vm#createvms", :defaults => { :format => 'xml'}
  match "usedips", :to => "vm#usedips", :defaults => { :format => 'xml'}
end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => 'welcome#index'
  root :to => 'dashboard#login'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'

  # Allow downloading Web Service WSDL as a file with an extension
  # instead of a file named 'wsdl'
  match ':controller/service.wsdl', :action => 'wsdl'

  # Install the default route as the lowest priority.
  match ':controller(.:format)', :action => :index
  match ':controller(/:action(/:id))(.:format)', :action => :index
end
