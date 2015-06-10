require 'net/http'

case node['os']
when "linux"
  install_cmds = value_for_platform(
    ["ubuntu"] => {
          "12.04" => ["apt-key adv --fetch-keys http://ossec.wazuh.com/repos/apt/conf/ossec-key.gpg.key", "echo 'deb http://ossec.wazuh.com/repos/apt/ubuntu precise main' >> /etc/apt/sources.list", "apt-get update"],
          "14.04" => ["apt-key adv --fetch-keys http://ossec.wazuh.com/repos/apt/conf/ossec-key.gpg.key", "echo 'deb http://ossec.wazuh.com/repos/apt/ubuntu trusty main' >> /etc/apt/sources.list", "apt-get update"],
          "14.10" => ["apt-key adv --fetch-keys http://ossec.wazuh.com/repos/apt/conf/ossec-key.gpg.key", "echo 'deb http://ossec.wazuh.com/repos/apt/ubuntu utopic main' >> /etc/apt/sources.list", "apt-get update"],
      "default" => ["apt-key adv --fetch-keys http://ossec.wazuh.com/repos/apt/conf/ossec-key.gpg.key", "echo 'deb http://ossec.wazuh.com/repos/apt/ubuntu precise main' >> /etc/apt/sources.list", "apt-get update"]
    },
    ["debian"] => {
          "8.0" => ["apt-key adv --fetch-keys http://ossec.wazuh.com/repos/apt/conf/ossec-key.gpg.key", "echo 'deb http://ossec.wazuh.com/repos/apt/debian jessie main' >> /etc/apt/sources.list", "apt-get update"],
          "7.0" => ["apt-key adv --fetch-keys http://ossec.wazuh.com/repos/apt/conf/ossec-key.gpg.key", "echo 'deb http://ossec.wazuh.com/repos/apt/debian wheezy main' >> /etc/apt/sources.list", "apt-get update"],
          "6.0" => ["apt-key adv --fetch-keys http://ossec.wazuh.com/repos/apt/conf/ossec-key.gpg.key", "echo 'deb http://ossec.wazuh.com/repos/apt/debian sid main' >> /etc/apt/sources.list", "apt-get update"],
      "default" => ["apt-key adv --fetch-keys http://ossec.wazuh.com/repos/apt/conf/ossec-key.gpg.key", "echo 'deb http://ossec.wazuh.com/repos/apt/debian wheezy main' >> /etc/apt/sources.list", "apt-get update"]
    },
    ["centos", "redhat", "fedora"] => {
      "default" => ["cd /root && wget -q -O /root/atomic https://www.atomicorp.com/installers/atomic && sed -i 's/^check_input \\\"Do you agree to these terms\\\?.*$//g' /root/atomic && sh /root/atomic && rm -f /root/atomic"]
    }
  )
  install_packs = value_for_platform(
   ["ubuntu", "debian"] => {"default" => ["ossec-hids-agent"]},
   ["centos", "redhat", "fedora"] => {"default" => ["ossec-hids-client"]}
  )
  servicesarr = value_for_platform(
   ["ubuntu", "debian"] => {"default" => ["ossec"]},
   ["centos", "redhat", "fedora", "amazon"] => {"default" => ["ossec-hids"]}
  )

if node['platform'] != "amazon" and node['platform'] != "debian" and node['platform'] != "ubuntu"
 install_cmds.each do |command|
  execute "#{command}" do
   not_if "test -f /var/ossec/etc/ossec.conf"
  end
 end

 install_packs.each do |pkg|
  package pkg do
   action :install
   options "--nogpgcheck"
  end
 end
end

if node['platform'] == "debian" or node['platform'] == "ubuntu"
 install_cmds.each do |command|
  execute "#{command}" do
   not_if "test -f /var/ossec/etc/ossec.conf"
  end
 end

 install_packs.each do |pkg|
  package pkg do
   action :install
  end
 end
end

 end

if node['platform'] == "amazon"
 template "/etc/yum.repos.d/atomic.repo" do
  source "atomic.repo.erb"
  owner "root"
  group "root"
  mode 0755
 end
 execute "Create key for repo" do
  command "wget -q --no-check-certificate https://www.atomicorp.com/RPM-GPG-KEY.art.txt 1>/dev/null 2>&1 && rpm -import RPM-GPG-KEY.art.txt >/dev/null 2>&1 && rm -f RPM-GPG-KEY.art.txt"
  not_if "test -f /etc/pki/rpm-gpg/RPM-GPG-KEY.art.txt"
  cwd "/root"
  action :run
 end
 package "ossec-hids-client"
end

#Get servername and agent name if config file exists
@config_data={}
if FileTest.exists?("/etc/ossec_config.conf")
 file = File.open("/etc/ossec_config.conf", 'r')
 file.each do |line|
  split_line=line.split("=")
  @config_data[split_line[0]]=split_line[1].gsub(/\n/, '')
 end
end

data_bag_vars=nil
#Get databag items set as JSON in berkshelf
begin
 data_bag_vars = data_bag_item("ossec", "user")
rescue => e
 puts("No databag available")
end

@agent_name=nil
@server_ip=nil

#Get agent name
if @config_data['agent_name'] != nil
 @agent_name=@config_data['agent_name']
elsif data_bag_vars != nil
 @agent_name=data_bag_vars['agent_name']
end

if @agent_name == nil
 begin
  uri = URI('http://169.254.169.254/latest/meta-data/instance-id')
  response = Net::HTTP.get(uri)
  @agent_name=response.gsub(/\n/,'')
 rescue => e
  puts("Using hostname as the actual agent name")
 end
 if @agent_name == nil
  @agent_name=IO.popen("hostname").readlines[0].gsub(/\..*$/, '').gsub(/\n/, '')
 end
end

ossec_server = Array.new

if node.run_list.roles.include?(node['ossec']['server_role'])
  ossec_server << node['ipaddress']
end

node.set['ossec']['user']['install_type'] = "agent"
if data_bag_vars != nil
 node.set['ossec']['user']['agent_server_hostname'] = data_bag_vars['agent_server_hostname']
 @server_ip = data_bag_vars['agent_server_hostname']
end

if @server_ip == nil
 node.set['ossec']['user']['agent_server_hostname']=@config_data['agent_server_hostname']
 @server_ip=@config_data['agent_server_hostname']
end
if @server_ip == nil
 puts("Error - agent server IP not specified neither in the databag nor in a config file")
 exit(1)
end

node.save unless Chef::Config[:solo]

user "ossecd" do
  comment "OSSEC Distributor"
  shell "/bin/bash"
  system true
  gid "ossec"
  home node['ossec']['user']['dir']
end

directory "#{node['ossec']['user']['dir']}/.ssh" do
  owner "ossecd"
  group "ossec"
  mode 0750
end

template "#{node['ossec']['user']['dir']}/etc/ossec-agent.conf" do
  source "ossec.conf.erb"
  owner "root"
  group "ossec"
  mode 0440
  variables(:ossec => node['ossec']['user'])
  #notifies :restart, "service[ossec]"
end

case node['platform']
when "arch"
  template "/etc/rc.d/ossec" do
    source "ossec.rc.erb"
    owner "root"
    mode 0755
  end
end

service "#{servicesarr[0]}" do
  supports :status => true, :start => true, :stop => true, :restart => true
  action :enable
end

#Set commands
agent_create_note="Create agent key using /var/ossec/bin/agent-auth -m #{@server_ip} -A #{@agent_name}"
agent_create="/var/ossec/bin/agent-auth -m #{@server_ip} -A #{@agent_name}"
not_if_cmd="grep #{@agent_name} /var/ossec/etc/client.keys 2>/dev/null"

#Run auth
if node['platform'] == "debian"
 execute agent_create_note do
  command agent_create
  not_if not_if_cmd
  action :run
 end
 execute "/etc/init.d/ossec restart" do
  command "/etc/init.d/ossec restart"
  action :run
 end
else
 execute agent_create_note do
  command agent_create
  not_if not_if_cmd
  notifies :restart, "service[#{servicesarr[0]}]"
  action :run
 end
end
