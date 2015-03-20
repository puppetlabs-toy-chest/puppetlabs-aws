module PuppetX
  module Puppetlabs
    module AwsIngressRulesParser
      # for vpc accounts expand protocol=-1 into protocol=tcp,udp,icmp
      def self.rule_to_ip_permission_list(ec2, rule, self_ref)
        ip_permission = rule_to_ip_permission(ec2, rule, self_ref)

        if ip_permission[:ip_protocol] == -1 && !ec2.vpc_only_account?
          tcp  = Marshal.load(Marshal.dump(ip_permission)).merge!(ip_protocol: 'tcp')
          udp  = Marshal.load(Marshal.dump(ip_permission)).merge!(ip_protocol: 'udp')
          icmp = Marshal.load(Marshal.dump(ip_permission)).merge!(ip_protocol: 'icmp')
          icmp.delete :from_port
          icmp.delete :to_port

          [tcp, udp, icmp]
        else
          [ip_permission]
        end
      end

      # for non-vpc accounts collapse "identical" rules with
      # protocol=tcp,udp,icmp rule without protocol
      def self.ip_permissions_to_rules_list(ec2, ipps, self_ref)
        rules = ipps.map{|ipp| ip_permission_to_rule(ec2, ipp, self_ref)}

        categorized = {tcp: [], udp: [], icmp: [], none: []}
        rules.each do |rule|
          key = %w{tcp udp icmp}.include?(rule['protocol']) ? rule['protocol'] : 'none'
          categorized[key.to_sym] << rule
        end

        # go through tcp rules and search for matching udp and icmp
        # if found - drop them all from corresponding lists and attach
        # a rule without protocol into :none category
        categorized[:tcp].delete_if do |tcp_rule|
          udp_rule  = Marshal.load(Marshal.dump(tcp_rule)).merge! 'protocol' => 'udp'
          icmp_rule = Marshal.load(Marshal.dump(tcp_rule)).merge! 'protocol' => 'icmp'
          icmp_rule.delete 'port'

          if categorized[:udp].include?(udp_rule) &&
             categorized[:icmp].include?(icmp_rule)
            categorized[:udp].delete udp_rule
            categorized[:icmp].delete icmp_rule

            udp_rule.delete 'protocol'
            categorized[:none] << udp_rule
            true
          end
        end

        categorized[:tcp] + categorized[:udp] +
          categorized[:icmp] + categorized[:none]
      end

      def self.rule_to_ip_permission(ec2, rule, self_ref)
        # fallback to current group id if cidr is also absent
        security_group = rule['security_group'] ||
          (rule['cidr'] ? nil : self_ref.last)
        ports = Array(rule['port'])

        {
          ip_protocol: rule['protocol'] || -1,
          from_port: ports.first,
          to_port: ports.last,
          ip_ranges: Array(rule['cidr']).map {|c| {cidr_ip: c}},
          user_id_group_pairs: Array(security_group).map do |sg|
            { group_id: name_to_id(ec2, sg, self_ref)}
          end
        }.delete_if {|k,v| v.nil? || (v.is_a?(Array) && v.empty?)}
      end

      def self.ip_permission_to_rule(ec2, ipp, self_ref)
        h = {
          'protocol' => ipp[:ip_protocol] == -1 ? nil : ipp[:ip_protocol],
          'cidr'     => (ipp[:ip_ranges] || []).map{|ipr| ipr[:cidr_ip]},
          'port'     => [ipp[:from_port], ipp[:to_port]].
                          compact.map(&:to_s).uniq.map(&:to_i),
          'security_group' => (ipp[:user_id_group_pairs] || []).
            map {|ug| ug[:group_name] || id_to_name(ec2, ug[:group_id], self_ref) }.
            compact
        }.delete_if {|k,v| v.nil? || (v.is_a?(Array) && v.empty?)}

        h.delete 'security_group' if h['security_group'] == [self_ref.last]

        %w{cidr port security_group}.each do |at|
          next unless h[at]

          case h[at].size
          when 0 then h.delete(at)
          when 1 then h[at] = h[at].first
          end
        end

        h
      end

      def self.name_to_id(ec2, name, self_ref=nil)
        return name if name =~ /^sg-/
        return self_ref.first if self_ref && self_ref.last == name

        group_response = ec2.describe_security_groups(
          filters: [{name: 'group-name', values: [name]}])

        if group_response.data.security_groups.count == 0
          fail("No groups found with name: '#{name}'")
        elsif group_response.data.security_groups.count > 1
          Puppet.warning "Multiple groups found called #{name}"
        end

        group_response.data.security_groups.first.group_id
      end

      def self.id_to_name(ec2, id, self_ref={})
        return self_ref.last if self_ref && self_ref.first == id

        group_response = ec2.describe_security_groups(
          filters: [{name: 'group-id', values: [id]}])

        group_response.data.security_groups.first.group_name
      end
    end
  end
end
