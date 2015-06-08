require_relative '../../../puppet_x/puppetlabs/aws.rb'

module Puppet::Parser::Functions
  newfunction(:s3_file_content, :type => :rvalue, :doc => <<-ENDHEREDOC
              Downloads a file from aws s3 and returns the contents

              Requires three parameters:
                Bucket
                File
                Region

              ENDHEREDOC
             ) do |args|

     unless args.length == 3 then
       raise Puppet::ParseError, ("s3_file_content(): wrong number of arguments (#{args.length}; must be 3)")
     end

     bucket = args[0]
     filename = args[1]
     region = args[2]

     ["bucket", "filename", "region"].each do |param_name|
       var = eval(param_name)
        unless var.instance_of?(String) then
          raise Puppet::ParseError, ("Parameter [#{param_name}] is not a string.  It looks to be a #{var.class}")
        end
        if var.to_s == "" then
          raise Puppet::ParseError, ("Parameter [#{param_name}] cannot be blank")
        end
     end

     PuppetX::Puppetlabs::Aws.s3_client(region).get_object( bucket: bucket, key: filename).body.read
   end
end
