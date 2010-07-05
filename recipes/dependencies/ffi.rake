require 'rake'
require 'rake/clean'

namespace(:dependencies) do
  namespace(:ffi) do
    package = RubyInstaller::LibFFI
    directory package.target
    CLEAN.include(package.target)

    # Put files for the :download task
    package.files.each do |f|
      file_source = "#{package.url}/#{f}"
      file_target = "downloads/#{f}"
      download file_target => file_source

      # depend on downloads directory
      file file_target => "downloads"

      # download task need these files as pre-requisites
      task :download => file_target
    end

    # Prepare the :sandbox, it requires the :download task
    task :extract => [:extract_utils, :download, package.target] do
      # grab the files from the download task
      files = Rake::Task['dependencies:ffi:download'].prerequisites

      files.each { |f|
        extract(File.join(RubyInstaller::ROOT, f), package.target)
      }
    end

    # Apply patches
    task :prepare => ['dependencies:ffi:extract', :compiler] do
      patches = Dir.glob("#{package.patches}/*.patch").sort
      patches.each do |patch|
        cmd = "git apply --directory=#{package.target} #{patch}"
        `#{cmd}`
      end
    end

    # Prepare sources for compilation
    task :configure => ['dependencies:ffi:extract', :compiler] do
      cd package.target do
        msys_sh "./configure #{package.configure_options.join(' ')} --prefix=/mingw"
      end
    end

    task :compile => :configure do
      cd package.target do
        msys_sh "make"
      end
    end

    task :install => :compile do
      cd package.target do
        msys_sh "make install"
      end
    end
  end
end

task :ffi => [
  'dependencies:ffi:download',
  'dependencies:ffi:extract',
  'dependencies:ffi:prepare',
  'dependencies:ffi:configure',
  'dependencies:ffi:compile',
  'dependencies:ffi:install'
]

unless ENV['COMPAT']
  task :dependencies => [:ffi]
end