import geni.portal as portal
import geni.rspec.pg as rspec

request = portal.context.makeRequestRSpec()

node = request.XenVM("node")
node.disk_image = "urn:publicid:IDN+emulab.net+image+emulab-ops:UBUNTU22-64-STD"
node.routable_control_ip = "true"

node.addService(rspec.Execute(
    shell="/bin/bash",
    command="sudo bash /local/repository/install_docker.sh"
))

portal.context.printRequestRSpec()
