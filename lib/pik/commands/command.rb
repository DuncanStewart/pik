require 'optparse'

module Pik

  class QuitError < StandardError
  end
  
  class VersionUnknown < StandardError
  end
  
  class  Command

    attr_reader :config
    
    attr_reader :options
    
    attr_accessor :output
    
    attr_accessor :version
    
    attr_accessor :debug
    
    def self.cmd_name
      name.split('::').last.downcase.to_sym
    end
    
    def self.description
      new.options.to_s
    end
    
    def self.inherited(subclass)
      Commands.add(subclass)
    end
    
    def self.it(str)
      @summary = str
    end
    
    def self.summary
      @summary 
    end
    
    def self.aka(*aliases)
      @names = names + aliases
    end
    
    def self.names
      @names ||= [cmd_name]
    end

    def initialize(args=ARGV, config_=nil)
      @args    = args
      @options = OptionParser.new
      @config  = config_ || ConfigFile.new
      
      add_sigint_handler

      options.program_name = "pik #{self.class.names.join('|')}"
      command_options
      parse_options
      
      create(Pik.home) unless Pik.home.exist?
      delete_old_pik_script
    end

    def close
      editors.each{|e| e.write }
    end
    
    def editors
      @editors ||= []
    end
    
    def command_options
      options.separator ""
      options.separator self.class.summary
      options.separator ""
      options.separator help_message  
    end
    
    def parse_options
      options.on("--version", "-V", "Display pik version") do |value|
        @version = true
        puts pik_version
      end
      options.on("--debug", "-d", "Outputs debug information") do |value|
        @debug = true
        Log.level = :debug
      end
      options.parse! @args 
    end
 
    def help_message
    end
 
    def pik_version
      win_ver = "on #{`ver`.strip}" rescue ''
      "pik #{Pik::VERSION} #{win_ver}\nby Gordon Thiesfeld (gthiesfeld@gmail.com)\n\n" 
    end
    
    def find_config_from_path(path=Which::Ruby.find)
      config.find{|k,v| 
        Pathname(v[:path])== Pathname(path)
      }.first rescue nil
    end
    
    def current_gem_bin_path
      cfg = config[find_config_from_path]
      p = cfg[:gem_home] || default_gem_home 
      p + 'bin'
    end

    def default_gem_home
      gem_path.first
    end
    
    def actual_gem_home
      gem_path.last
    end
    
    def gem_path
      `\"#{Which::Gem.exe}\" env gempath`.chomp.split(';').map{|p| Pathname(p).to_windows }
    end
    
    def create(home)
      puts "creating #{home}"
      home.mkpath
    end
   
    def delete_old_pik_script
      Log.debug "Deleting #{Pik.script_file.path}"
      Pik.script_file.path.delete if Pik.script_file.path.exist?
    end
    
    def sh(*cmd)
      Log.debug cmd.join(' ') if debug
      system(*cmd)
    end
    
    def hl
      @hl ||= HighLine.new
    end

    def cmd_name
      self.class.cmd_name
    end

    # Installs a sigint handler.
  
    def add_sigint_handler
      trap 'INT' do
        raise QuitError
      end
    end
    
  end  
    
end
