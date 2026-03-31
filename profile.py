import geni.portal as portal
import geni.rspec.pg as rspec

request = portal.context.makeRequestRSpec()

# Define CloudLab parameters
portal.context.defineParameter(
    "github_token",
    "GitHub Token (used for GHCR login and backend)",
    portal.ParameterType.STRING,
    ""
)
portal.context.defineParameter(
    "api_key",
    "API Key (e.g. OpenAI)",
    portal.ParameterType.STRING,
    ""
)
params = portal.context.bindParameters()

node = request.XenVM("node")
node.disk_image = "urn:publicid:IDN+emulab.net+image+emulab-ops:UBUNTU22-64-STD"
node.routable_control_ip = "true"

# Step 1: Install Docker
node.addService(rspec.Execute(
    shell="/bin/bash",
    command="sudo bash /local/repository/install_docker.sh"
))

# Step 2: Write .env, login to GHCR, and bring up all containers
node.addService(rspec.Execute(
    shell="/bin/bash",
    command=(
        "export GITHUB_TOKEN='{github_token}' && "
        "export API_KEY='{api_key}' && "
        "sudo -E bash /local/repository/setup.sh"
    ).format(
        github_token=params.github_token,
        api_key=params.api_key,
    )
))

portal.context.printRequestRSpec()
