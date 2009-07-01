#Give this app a name

application_name = ask('What is this application called?')

#Install gems
gem 'RedCloth', :version => '3.0.4', :lib => 'redcloth'
gem 'aws-s3', :version => '0.6.2', :lib => 'aws/s3'
gem 'chriseppstein-compass', :version => '0.6.15', :lib => 'compass'
gem 'mocha'
gem 'thoughtbot-shoulda', :lib => 'shoulda'
gem 'thoughtbot-paperclip', :lib => 'paperclip'
gem 'thoughtbot-factory_girl', :lib => 'factory_girl'
gem 'thoughtbot-quietbacktrace', :lib => 'quietbacktrace'
gem 'mislav-will_paginate', :version => '~> 2.2.3', :lib => 'will_paginate'
gem 'rubyist-aasm', :lib => 'aasm'
gem 'haml-edge', :lib => 'haml'

rake 'gems:install', :sudo=>true
rake 'gems:unpack'

#install plugins
plugin 'hoptoad_notifier', :git => 'git://github.com/thoughtbot/hoptoad_notifier.git'
plugin 'asset_packager', :git => 'git://github.com/sbecker/asset_packager.git'
plugin 'limerick_rake', :git => "git://github.com/thoughtbot/limerick_rake.git"
plugin 'paperclip', :git => 'git://github.com/thoughtbot/paperclip.git'
plugin 'resource_controller', :git => 'git://github.com/giraffesoft/resource_controller.git'
plugin 'restful-authentication', :git => 'git://github.com/technoweenie/restful-authentication.git'
plugin 'role_requirement', :git => 'git://github.com/timcharper/role_requirement.git'
plugin 'squirrel', :git => "git://github.com/thoughtbot/squirrel.git"
file 'vendor/plugins/haml/init.rb', <<-END
require 'rubygems'
begin
require File.join(File.dirname(__FILE__), 'lib', 'haml') # From here
rescue LoadError
require 'haml' # From gem
end

# Load Haml and Sass
Haml.init_rails(binding)
END

#Setup Hoptoad
hoptoad_api_key = ask('What is your Hoptoad API key?')

initializer 'hoptoad.rb', <<-END
HoptoadNotifier.configure do |config|
config.api_key = '#{hoptoad_api_key}'
end
END

#Delete all unecessary files
run "rm README"
run "rm public/index.html"
run "rm public/favicon.ico"
run "rm public/robots.txt"

#Setup git ignore file
file '.gitignore', <<-END
config/database.yml
db/schema.rb
log/*.log
public/stylesheets/*.css
public/stylesheets/complied/*.css
*.swo
*.swp
tmp/
db/*.sqlite3
END
run 'touch tmp/.gitignore log/.gitignore'

# Set up sessions, user model, role, and run migrations
rake('db:sessions:create')
generate("authenticated", "user session")
generate("roles", "Role User")
rake('db:migrate')

gsub_file 'app/controllers/application_controller.rb', /(class ApplicationController.*)/, "\\1\n  include HoptoadNotifier"
gsub_file 'app/controllers/application_controller.rb', /#\s*(filter_parameter_logging :password)/, '\1'

smtp_password = ask('What is your SMTP password?')

# Set up session store initializer
initializer 'session_store.rb', <<-END
ActionController::Base.session = { :session_key => '_#{(1..6).map { |x| (65 + rand(26)).chr }.join}_session', :secret => '#{(1..40).map { |x| (65 + rand(26)).chr }.join}' }
ActionController::Base.session_store = :active_record_store
END

# Setup mailer initializer
initializer 'action_mailer_configs.rb', <<-END
ActionMailer::Base.smtp_settings = {
  :address         => 'smtp.gmail.com',
  :port            => 587, 
  :domain          => 'shovelpunks.com',
  :user_name       => 'mailer@shovelpunks.com',
  :password        => '#{smtp_password}',
  :authentication  => :plain
}
END

# Setup backtrace_silencer initialier
initializer 'backtrace_silencers.rb', <<-END
SHOULDA_NOISE      = %w( shoulda )
FACTORY_GIRL_NOISE = %w( factory_girl )
THOUGHTBOT_NOISE   = SHOULDA_NOISE + FACTORY_GIRL_NOISE
 
Rails.backtrace_cleaner.add_silencer do |line| 
  THOUGHTBOT_NOISE.any? { |dir| line.include?(dir) }
end
 
# When debugging, uncomment the next line.
# Rails.backtrace_cleaner.remove_silencers!
END

# Setup compass initializer
initializer 'compass.rb', <<-END
require 'compass'
# If you have any compass plugins, require them here.
Compass.configuration.parse(File.join(RAILS_ROOT, "config", "compass.config"))
Compass.configuration.environment = RAILS_ENV.to_sym
Compass.configure_sass_plugin!
END

# Setup mock initializer
initializer 'mocks.rb', <<-END
# This callback will run before every request to a mock in development mode, 
# or before the first server request in production. 
 
Rails.configuration.to_prepare do
  Dir[File.join(RAILS_ROOT, 'test', 'mocks', RAILS_ENV, '*.rb')].each do |f|
    load f
  end
end
END

# Create compass and asset packager configuration files
file 'config/compass.config', <<-END
# Require any additional compass plugins here.
project_type = :rails
project_path = RAILS_ROOT if defined?(RAILS_ROOT)
css_dir = "public/stylesheets"
sass_dir = "app/stylesheets"
images_dir = "public/images"
javascripts_dir = "public/javascripts"
# To enable relative image paths using the images_url() function:
# http_images_path = :relative
http_images_path = "/images"
END

file 'config/asset_packages.yml', <<-END
--- 
javascripts: 
- base: 
  - sound
  - slider
  - scriptaculous
  - prototype
  - effects
  - dragdrop
  - controls
  - builder
  - application
stylesheets: 
- base: 
  - screen
END


# Create a basic layout
file 'app/views/layouts/application.html.haml', <<-END
!!!
%html{:xmlns=>"http://www.w3.org/1999/xhtml", 'xml:lang'=>"en" :lang=>"en"}
  %head
    %meta{:name=>:description, :content=>'#{application_name}'}
    %meta{:name=>:keywords, :content=>'#{application_name}'}
    %meta{:name=>:author, :content=>'#{application_name}'}
  
    = stylesheet_link_merged 'screen.css', :media => 'screen, projection'
    = stylesheet_link_merged 'print.css', :media => 'print'
    /[if IE]
      = stylesheet_link_merged 'ie.css', :media => 'screen, projection'
  
    %title= yield :title
 
  %body
    .container
      #header
        = render :partial => 'layouts/header'
      
      #body.content
        = render :partial => 'layouts/flashes'
        = yield
      
      #footer
        = render :partial => 'layouts/footer'
    
    = render :partial => 'layouts/javascript'
    = render :partial => 'layouts/tracking'
END

file 'app/views/layouts/_tracking.html.haml', <<-END
/ No tracking code has been installed
END

file 'app/views/layouts/_javascript.html.haml', <<-END
= javascript_include_merged :defaults
= yield :javascript
END

file 'app/views/layouts/_header.html.haml', <<-END
This is the header
END

file 'app/views/layouts/_footer.html.haml', <<-END
This is the footer
END

file 'app/views/layouts/_flashes.html.haml', <<-END
#flash
  - flash.each do |key, value| 
    %div{:id=>key}
    = h value
END

# Setup stylesheets
file 'app/stylesheets/screen.sass', <<-END
@import blueprint.sass
@import blueprint/modules/scaffolding.sass
@import compass/reset.sass
 
+blueprint
// Remove the scaffolding when you're ready to start doing visual design.
// Or leave it in if you're happy with how blueprint looks out-of-the-box
+blueprint-scaffolding
END

file 'app/stylesheets/print.sass', <<-END
@import blueprint.sass
 
+blueprint-print
END

file 'app/stylesheets/ie.sass', <<-END
@import blueprint.sass
 
+blueprint-ie
END

# Create a simple page controller
file 'app/controllers/home_controller.rb', <<-END
class HomeController < ApplicationController
  def index
    # render the landing page
  end

  def show
    render :action => params[:page]
  end
end
END

gsub_file 'config/routes.rb', /^(ActionController.*)/, <<-END
\\1
  map.root :controller => 'home'
  map.home ':page', :controller => 'home', :action => 'show', :page => /about|contact/
  map.page 'page/:page', :controller => 'home', :action => 'show', :page => /about|contact/
END

file 'app/views/home/index.html.haml', <<-END
%h1 The Home Page
END

file 'app/views/home/contact.html.haml', <<-END
%h1 The Contact Us Page
END

file 'app/views/home/about.html.haml', <<-END
%h1 The About Page
END

#add to git
git :init
git :add => '.'
git :commit => "-a -m 'Initial commit'"

