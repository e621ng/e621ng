Vagrant.configure('2') do |config|
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true

  config.vm.box = 'debian/stretch64'
  config.vm.box_version = '9.4.0'

  config.vm.provider 'virtualbox' do |v|
    v.cpus = 2
    v.memory = 1280
    if Vagrant::Util::Platform.windows?
      v.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate//vagrant", "1"]
    end
  end

  VAGRANT_COMMAND = ARGV[0]
  config.ssh.username = 'danbooru' if VAGRANT_COMMAND == 'ssh'

  config.vm.define 'default' do |node|
    node.vm.hostname = 'e621.lc'
    node.vm.network :private_network, ip: '192.168.64.78'
  end

  if Vagrant::Util::Platform.windows?
    config.vm.synced_folder '.', '/vagrant', type: 'virtualbox'
  else
    config.vm.synced_folder '.', '/vagrant', type: 'nfs'
  end

  config.vm.provision 'shell', path: 'vagrant/install.sh'
end

