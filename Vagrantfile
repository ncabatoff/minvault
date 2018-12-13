Vagrant.configure("2") do |config|
  config.vm.box = "debian/jessie64"
  config.vm.provision "vault",   type: "shell", path: "vault.sh"
end
