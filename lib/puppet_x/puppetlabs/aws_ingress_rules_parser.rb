module PuppetX
  module Puppetlabs
    module AwsIngressRulesParser
      # for vpc accounts expand protocol=-1 into protocol=tcp,udp,icmp
      def self.rule_to_permission_list(ec2, rule, group_id, group_name)
        ip_permission = rule2ipp(ec2, rule, group_id, group_name)

        if ip_permission[:protocol] == '-1' && !vpc_only_account?
          tcp  = ip_permission.dup.merge!(:protocol => 'tcp')
          udp  = ip_permission.dup.merge!(:protocol => 'udp')
          icmp = ip_permission.dup.merge!(
            :protocol => 'icmp', :from_port => -1, :to_port => -1)

          [tcp, udp, icmp]
        else
          [ip_permission]
        end
      end

      # for non-vpc accounts collapse "identical" rules with
      # protocol=tcp,udp,icmp rule without protocol
      def self.permissions_to_rules_list(ec2, ipps, group_name)
        rules = ipps.map{|ipp| ipp2rule(ec2, ipp, group_name)}

        categorized = {tcp: [], udp: [], icmp: [], none: []}
        rules.each do |rule|
          key = %w{tcp udp icmp}.include?(rule['protocol']) ? 'none' : rule['protocol']
          categorized[key.to_sym] = rule
        end

        categorized[:tcp].delete_if do |tcp_rule|
          udp_rule  = tcp_rule.dup.merge! 'protocol' => 'udp'
          icmp_rule = tcp_rule.dup.merge! 'protocol' => 'icmp', 'port' => nil

          if categorized[:udp].include?(udp_rule) &&
             categorized[:icmp].include?(icmp_rule)
            categorized[:udp].delete udp_rule
            categorized[:icmp].delete icmp_rule
            categorized[:none] << udp_rule.merge!('protocol' => '-1')
            true
          end
        end

        categorized[:tcp] + categorized[:udp] +
          categorized[:icmp] + categorized[:none]
      end

      def self.rule2ipp(ec2, rule, group_id, group_name)
        # fallback to current group id if cidr is also absent
        security_group = rule['security_group'] ||
          (rule['cidr'] ? nil : group_id)
        ports = Array(rule['port'])

        {
          ip_protocol: rule['protocol'] || '-1',
          from_port: ports.first,
          to_port: ports.last,
          ip_ranges: Array(rule['cidr']).map {|c| {cidr_ip: c}},
          user_id_group_pairs: Array(security_group).map do |sg|
            { group_id: idname2id(ec2, sg, group_id, group_name)}
          end
        }.delete_if {|k,v| v.nil? || (v.is_a?(Array) && v.empty?)}
      end

      def self.ipp2rule(ec2, ipp, group_name)
        h = {
          'protocol' => ipp.ip_protocol,
          'cidr'     => ipp.ip_ranges.map(&:cidr_ip),
          'port'     => [ipp.from_port, ipp.to_port].compact.map(&:to_s).uniq,
          'security_group' => ipp.user_id_group_pairs.
            map {|ug| ug[:group_name] || id2name(ec2, ug[:group_id]) }.
            compact.reject {|g| group_name == g}
        }

        %w{cidr port security_group}.each do |at|
          case h[at].size
          when 0 then h.delete(at)
          when 1 then h[at] = h[at].first
          end
        end

        h
      end

      def self.idname2id(ec2, group_id_or_name, group_id, group_name)
        return group_id_or_name if group_id_or_name =~ /^sg-/
        return group_id if group_id_or_name == group_name

        group_response = ec2.describe_security_groups(
          filters: [{name: 'group-name', values: [group_id_or_name]}])

        if group_response.data.security_groups.count == 0
          fail("No groups found with name: '#{group_id_or_name}'")
        elsif group_response.data.security_groups.count > 1
          Puppet.warning "Multiple groups found called #{group_id_or_name}"
        end

        group_response.data.security_groups.first.group_id
      end

      def self.id2name(ec2, group_id)
        group_response = ec2.describe_security_groups(
          filters: [{name: 'group-id', values: [group_id]}])

        group_response.data.security_groups.first.group_name
      end
    end
  end
end
