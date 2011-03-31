module Minion
  module Daemon
    extend self
    attr_accessor :pid, :log
    
    def fork_or_skip
      
      arg = ARGV.join(" ")[/\-d\s\d+/] || ARGV.join(" ")[/\-d/]

      return unless arg
      workers = (arg[/\d+/] || 1).to_i
      
      if workers == 1
        fork!
      else
        workers.times do |i|
          puts "starting worker #{i}"
          `cd #{Dir.pwd} && MINION_WORKER=#{i} #{ENV['_']} #{$0} -d`
        end
        exit
      end
    end
    
    def fork!
      ensure_dirs
      process_num = ENV['MINION_WORKER']
      
      exit!(0) if fork()
      
      Process.setsid()
      
      try_kill_previous(process_num)  if pid
      write_pid(process_num)          if pid
      
      write_logs(process_num)
    end
    
    def pid_folder
      File.dirname(pid)
    end
    
    def log_folder
      File.dirname(log)
    end
    
    def ensure_dirs
      `mkdir -p #{File.join(Dir.pwd, pid_folder)}` if pid
      `mkdir -p #{File.join(Dir.pwd, log_folder)}` if log
    end
    
    def file_for(method, number)
      File.join(Dir.pwd, send(method)) + ".#{number}"
    end
    
    def write_pid(number)
      File.open(file_for(:pid, number), 'w') {|file| file.write(Process.pid())}
    end
    
    def write_logs(number)
      $stdin.close()
      if log
        $stdout.reopen(File.join(Dir.pwd, log), "a")
        $stdout.sync = true
        $stderr.reopen($stdout)
        #$stderr.reopen(file_for(:log, number) + '.err', "w")
      else
        $stdout.reopen('/dev/null', "w")
        $stderr.reopen('/dev/null', "w")
      end
      
    end
    
    def try_kill_previous(number)
      return unless pid
      pidfile = file_for(:pid, number)
      
      if File.exist?(pidfile)
        pid_to_kill = File.open(pidfile) {|f| f.read }
        
        Process.kill("HUP", pid_to_kill.to_i) rescue nil
      end
    end
    
  end
end