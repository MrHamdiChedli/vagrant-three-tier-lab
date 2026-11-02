require "securerandom"

# The DB password is generated once and stays out of Git (see .gitignore).
SECRET_FILE = File.join(__dir__, ".db_password")
File.write(SECRET_FILE, SecureRandom.hex(16)) unless File.exist?(SECRET_FILE)
DB_PASSWORD = File.read(SECRET_FILE).strip

NETWORK = {
  "LB_IP"   => "192.168.56.10",
  "WEB1_IP" => "192.168.56.11",
  "WEB2_IP" => "192.168.56.12",
  "DB_IP"   => "192.168.56.20",
}

# Boot order matters: the database first, the load balancer last.
NODES = [
  { name: "db",   ip: NETWORK["DB_IP"],   memory: 1024, script: "provision/db.sh" },
  { name: "web1", ip: NETWORK["WEB1_IP"], memory: 512,  script: "provision/web.sh" },
  { name: "web2", ip: NETWORK["WEB2_IP"], memory: 512,  script: "provision/web.sh" },
  { name: "lb",   ip: NETWORK["LB_IP"],   memory: 512,  script: "provision/lb.sh" },
]

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.boot_timeout = 600

  config.vm.provider "virtualbox" do |vb|
    vb.linked_clone = true # the VMs share the box's disk, which saves a lot of space
    vb.cpus = 1
  end

  NODES.each do |node|
    config.vm.define node[:name] do |machine|
      machine.vm.hostname = node[:name]
      machine.vm.network "private_network", ip: node[:ip]
      machine.vm.provider("virtualbox") { |vb| vb.memory = node[:memory] }
      machine.vm.provision "shell", path: node[:script],
                                    env: NETWORK.merge("DB_PASSWORD" => DB_PASSWORD)
    end
  end
end
