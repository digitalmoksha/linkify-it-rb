if defined?(Motion::Project::Config)

  lib_dir_path = File.dirname(File.expand_path(__FILE__))
  Motion::Project::App.setup do |app|
    app.files.unshift(Dir.glob(File.join(lib_dir_path, 'linkify-it-rb/**/*.rb')))

    app.files_dependencies File.join(lib_dir_path, 'linkify-it-rb/index.rb') => File.join(lib_dir_path, 'linkify-it-rb/re.rb')
  end

  require 'uc.micro-rb'

else

  require 'uc.micro-rb'
  require 'linkify-it-rb/re'
  require 'linkify-it-rb/index'

end