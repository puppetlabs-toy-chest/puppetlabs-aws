require 'yaml'
require 'fileutils'

FOG_PATH = File.expand_path('~/.fog')
AWS_CREDS_DIR = File.expand_path('~/.aws')
AWS_CREDS_PATH = File.join(AWS_CREDS_DIR, 'credentials')

if File.exist?(FOG_PATH) && !File.exist?(AWS_CREDS_PATH)
  FileUtils.mkdir_p(AWS_CREDS_DIR)
  puts "Fog credentials found, creating #{AWS_CREDS_PATH}"
  data = YAML.load_file(FOG_PATH)
  File.open(AWS_CREDS_PATH, 'w') do |io|
    io.puts <<EOF
[default]

aws_access_key_id=#{data[:default][:aws_access_key_id]}
aws_secret_access_key=#{data[:default][:aws_secret_access_key]}
EOF
  end
else
  puts 'Fog credentials not found / AWS credentials already exist'
end
