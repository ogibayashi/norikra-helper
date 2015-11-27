require 'time'
require 'norikra/client/cli/parser'
require 'norikra/client/cli/formatter'

module Norikra::Helper
  module LogReader
    extend Norikra::Client::CLIUtil
    
    def self.process(in_file, out_file, options)
      parser = parser("json")
      formatter = formatter("json")
      start_time = nil
      File.open(in_file) do |i|
        File.open(out_file, 'w') do |o|
          prev_log = nil
          i.each_line do |line|
            # Assume "[time]\t[log]" format if time_key is not specified
            unless options[:time_key]
              (time_str,line) = line.split("\t",2)
            end
            log = parser.parse(line)
            time_str ||= log[options[:time_key]]
            time = Time.strptime(time_str, options[:time_format])
            start_time ||= time
            log['t'] = (time - start_time).to_f
            if prev_log && log['t'].to_i != prev_log['t'].to_i
              prev_log.merge!({  "flush" => true, "wait_till" => log['t']})
            end
            o.puts formatter.format(prev_log) if prev_log
            prev_log = log
          end
          o.puts formatter.format(prev_log.merge({  "flush" => true}))
        end
      end
    end

  end
end
