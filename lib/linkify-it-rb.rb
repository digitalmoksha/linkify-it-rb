# encoding: utf-8

if defined?(Motion::Project::Config)

  lib_dir_path = File.dirname(File.expand_path(__FILE__))
  Motion::Project::App.setup do |app|
    app.files.unshift(Dir.glob(File.join(lib_dir_path, "linkify-it-rb/**/*.rb")))
  end

  require 'uc.micro-rb'

else

  require 'uc.micro-rb'
  require 'linkify-it-rb/linkify_re'
  require 'linkify-it-rb/index'

end