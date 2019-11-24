# -*- mode: ruby -*-
# vi: ft=ruby :

require 'rbconfig'
require 'yaml'

# Set your default base box here
DEFAULT_BASE_BOX = 'gusztavvargadr/windows-server'

#
# No changes needed below this point
#

VAGRANTFILE_API_VERSION = '2'
PROJECT_NAME = '/' + File.basename(Dir.getwd)

hosts = YAML.load_file('vagrant-hosts.yml')

# {{{ Helper functions

def is_windows
  RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
end

# Set options for the network interface configuration. All values are
# optional, and can include:
# - ip (default = DHCP)
# - netmask (default value = 255.255.255.0
# - mac
# - auto_config (if false, Vagrant will not configure this network interface
# - intnet (if true, an internal network adapter will be created instead of a
#   host-only adapter)
def network_options(host)
  options = {}

  if host.has_key?('ip')
    options[:ip] = host['ip']
    options[:netmask] = host['netmask'] ||= '255.255.255.0'
  else
    options[:type] = 'dhcp'
  end

  if host.has_key?('mac')
    options[:mac] = host['mac'].gsub(/[-:]/, '')
  end
  if host.has_key?('auto_config')
    options[:auto_config] = host['auto_config']
  end
  if host.has_key?('intnet') && host['intnet']
    options[:virtualbox__intnet] = true
  end

  options
end

def custom_synced_folders(vm, host)
  if host.has_key?('synced_folders')
    folders = host['synced_folders']

    folders.each do |folder|
      vm.synced_folder folder['src'], folder['dest'], folder['options']
    end
  end
end

def extra_vbox_settings(vm)
  vm.provider :virtualbox do |vbw|
    vbw.gui = true
    vbw.customize ["modifyvm", :id, "--vram", "256"]
    vbw.customize ["modifyvm", :id, "--accelerate3d", "on"]
    vbw.customize ["modifyvm", :id, "--accelerate2dvideo", "on"]
    vbw.customize ["modifyvm", :id, "--graphicscontroller", "vboxsvga"]
    vbw.customize ["modifyvm", :id, "--paravirtprovider", "default"] # "hyperv" is buggy?
    vbw.customize ["modifyvm", :id, "--clipboard", "bidirectional"]
    vbw.customize ["modifyvm", :id, "--draganddrop", "bidirectional"]
    vbw.customize ["modifyvm", :id, "--memory", 4096]
    vbw.customize ["modifyvm", :id, "--cpus", 2]
  end
end

# }}}

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.ssh.insert_key = false
  config.winrm.timeout = 200
  config.winrm.retry_limit = 15
  config.winrm.retry.delay = 20
  config.winrm.ssl_peer_verification = false
  config.winrm.transport = :plaintext
  config.winrm.basic_auth_only = true
  hosts.each do |host|
    config.vm.define host['name'] do |node|
      node.vm.box = host['box'] ||= DEFAULT_BASE_BOX
      if(host.key? 'box_url')
        node.vm.box_url = host['box_url']
      end

      node.vm.hostname = host['name']
      node.vm.network :private_network, network_options(host)
      custom_synced_folders(node.vm, host)

      extra_vbox_settings(node.vm)
      
      # Run configuration script for the VM
      #node.vm.provision 'shell', path: 'provisioning/' + host['name'] + '.ps1'
      #node.vm.provision 'shell', path: 'provisioning/' + host['name'] + '-step1.ps1', reboot: true
      node.vm.provision 'shell', path: 'provisioning/' + host['name'] + '-step1.ps1'
      node.vm.provision :reload
      node.vm.provision 'shell', inline: "write-host 'post reboot operaties'"
      #node.vm.provision 'shell', path: 'provisioning/' + host['name'] + '-step2.ps1'
      #node.vm.provision 'shell', path: 'provisioning/' + host['name'] + '-test.ps1'
      #node.vm.provision :reload
      #node.vm.provision 'shell', path: 'provisioning/' + host['name'] + '-test.ps1'
    end
  end
end

