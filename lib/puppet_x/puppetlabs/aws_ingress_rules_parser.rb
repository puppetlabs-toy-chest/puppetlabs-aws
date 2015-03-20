module PuppetX
  module Puppetlabs
    class AwsIngressRulesParser


        def initialize(rules)
          @rules = []
          @rules << rules.reject(&:nil?).collect do |rule|
            # expand port to to_port and from_port
            new_rule = Marshal.load(Marshal.dump(rule))
            if rule.key? 'port'
              value = rule['port']
              new_rule.delete 'port'
              new_rule['from_port'] = value.to_i
              new_rule['to_port'] = value.to_i
            end
            # add default ports if missing
            unless new_rule.key? 'to_port'
              if rule['protocol'] == 'icpm'
                new_rule['from_port']= -1
                new_rule['to_port']= -1
              else
                new_rule['from_port']= 1
                new_rule['to_port']= 65535
              end
            end
            # expand when protocol not specified
            unless rule['protocol']
              ['tcp', 'udp'].each do |proto|
                copy = Marshal.load(Marshal.dump(new_rule))
                copy['protocol'] = proto
                @rules << copy
              end
              new_rule['protocol'] = 'icmp'
              if new_rule.key? 'to_port'
                new_rule['to_port'] = -1
                new_rule['from_port'] = -1
              end
            end
            new_rule
          end
          @rules = @rules.flatten

        end

        def rules_to_create(rules)
          stringify_values(@rules) - stringify_values(rules)
        end

        def rules_to_delete(rules)
          stringify_values(rules) - stringify_values(@rules)
        end

        private
        def stringify_values(rules)
          rules.collect do |obj|
            obj.each { |k,v| obj[k] = v.to_s }
          end
        end

    end
  end
end
