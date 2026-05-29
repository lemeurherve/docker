# Setup containerd by following the setup instructions here. (Currently, we only support the containerd worker.)
## install-containerd.ps1





## From https://github.com/containerd/containerd/blob/be50f8f1b23e359e65e066740097e089c275929b/docs/getting-started.md\#installing-containerd-on-windows

# If containerd previously installed run:
Stop-Service containerd

# Download and extract desired containerd Windows binaries
$Version="1.7.13"	# update to your preferred version
$Version="2.2.1"	# update to your preferred version
$Arch = "amd64"	# arm64 also available
curl.exe -LO https://github.com/containerd/containerd/releases/download/v$Version/containerd-$Version-windows-$Arch.tar.gz
tar.exe xvf .\containerd-$Version-windows-$Arch.tar.gz

# Copy
Copy-Item -Path .\bin -Destination $Env:ProgramFiles\containerd -Recurse -Force

# add the binaries (containerd.exe, ctr.exe) in $env:Path
$Path = [Environment]::GetEnvironmentVariable("PATH", "Machine") + [IO.Path]::PathSeparator + "$Env:ProgramFiles\containerd"
[Environment]::SetEnvironmentVariable( "Path", $Path, "Machine")
# reload path, so you don't have to open a new PS terminal later if needed
$Env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# configure
containerd.exe config default | Out-File $Env:ProgramFiles\containerd\config.toml -Encoding ascii
# Review the configuration. Depending on setup you may want to adjust:
# - the sandbox_image (Kubernetes pause image)
# - cni bin_dir and conf_dir locations
Get-Content $Env:ProgramFiles\containerd\config.toml

# Register and start service
containerd.exe --register-service
Start-Service containerd






# Setup the CNI, see details in the CNI / Networking Setup section.
## setup-cni.ps1


## From https://github.com/moby/buildkit/blob/c8178843b73773f1703bd73f5101041da4506157/docs/windows.md#cni--networking-setup

# get the CNI plugins (binaries)
$cniPluginVersion = "0.3.1"
$cniBinDir = "$env:ProgramFiles\containerd\cni\bin"
mkdir $cniBinDir -Force
curl.exe -fSLO https://github.com/microsoft/windows-container-networking/releases/download/v$cniPluginVersion/windows-container-networking-cni-amd64-v$cniPluginVersion.zip
tar xvf windows-container-networking-cni-amd64-v$cniPluginVersion.zip -C $cniBinDir

# NOTE: depending on your host setup, the IPs may change after restart
# you can only run this script from here to end for a refresh.
# without downloading the binaries again.

$cniVersion = "1.0.0"
$cniConfPath = "$env:ProgramFiles\containerd\cni\conf\0-containerd-nat.conf"

$networkName = 'nat'
# Get-HnsNetwork is available once you have enabled the 'Hyper-V Host Compute Service' feature
# which must have been done at the Quick setup above
# Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V, Containers -All
# the default one named `nat` should be available, except for WS2019, see notes below.
$natInfo = Get-HnsNetwork -ErrorAction Ignore | Where-Object { $_.Name -eq $networkName }
if ($null -eq $natInfo) {
    throw "NAT network not found, check if you enabled containers, Hyper-V features and restarted the machine"
}
$gateway = $natInfo.Subnets[0].GatewayAddress
$subnet = $natInfo.Subnets[0].AddressPrefix

$natConfig = @"
{
    "cniVersion": "$cniVersion",
    "name": "$networkName",
    "type": "nat",
    "master": "Ethernet",
    "ipam": {
        "subnet": "$subnet",
        "routes": [
            {
                "gateway": "$gateway"
            }
        ]
    },
    "capabilities": {
        "portMappings": true,
        "dns": true
    }
}
"@
Set-Content -Path $cniConfPath -Value $natConfig
# take a look
cat $cniConfPath

# quick test with nanoserver:ltsc20YY (YMMV)
$YY = 22
ctr i pull mcr.microsoft.com/windows/nanoserver:ltsc20$YY
ctr run --rm --cni mcr.microsoft.com/windows/nanoserver:ltsc20$YY cni-test cmd /C curl -I example.com







# Start the containerd service, if not yet started.

# Download and extract:

# $url = "https://api.github.com/repos/moby/buildkit/releases/latest"
# $version = (Invoke-RestMethod -Uri $url -UseBasicParsing).tag_name
# $arch = "amd64" # arm64 binary available too
# curl.exe -fSLO https://github.com/moby/buildkit/releases/download/$version/buildkit-$version.windows-$arch.tar.gz
# # there could be another `.\bin` directory from containerd instructions
# # you can move those
# mv bin bin2
# tar.exe xvf .\buildkit-$version.windows-$arch.tar.gz
# ## x bin/
# ## x bin/buildctl.exe
# ## x bin/buildkitd.exe




## From https://github.com/moby/buildkit/blob/master/docs/windows.md#setup-instructions

$url = "https://api.github.com/repos/moby/buildkit/releases/latest"
$version = (Invoke-RestMethod -Uri $url -UseBasicParsing).tag_name
$arch = "amd64" # arm64 binary available too
curl.exe -fSLO https://github.com/moby/buildkit/releases/download/$version/buildkit-$version.windows-$arch.tar.gz
# there could be another `.\bin` directory from containerd instructions
# you can move those
mv bin bin2
tar.exe xvf .\buildkit-$version.windows-$arch.tar.gz
## x bin/
## x bin/buildctl.exe
## x bin/buildkitd.exe


# after the binaries are extracted in the bin directory
# move them to an appropriate path in your $Env:PATH directories or:
Copy-Item -Path ".\bin" -Destination "$Env:ProgramFiles\buildkit" -Recurse -Force
# add `buildkitd.exe` and `buildctl.exe` binaries in the $Env:PATH
$Path = [Environment]::GetEnvironmentVariable("PATH", "Machine") + `
    [IO.Path]::PathSeparator + "$Env:ProgramFiles\buildkit"
[Environment]::SetEnvironmentVariable( "Path", $Path, "Machine")
$Env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + `
    [System.Environment]::GetEnvironmentVariable("Path","User")

# Start buildkitd.exe, you should see something similar to:

# PS C:\> buildkitd.exe
# time="2024-02-26T10:42:16+03:00" level=warning msg="using null network as the default"
# time="2024-02-26T10:42:16+03:00" level=info msg="found worker \"zcy8j5dyjn3gztjv6gv9kn037\", labels=map[org.mobyproject.buildkit.worker.containerd.namespace:buildkit org.mobyproject.buildkit.worker.containerd.uuid:c30661c1-5115-45de-9277-a6386185a283 org.mobyproject.buildkit.worker.executor:containerd org.mobyproject.buildkit.worker.hostname:[deducted] org.mobyproject.buildkit.worker.network: org.mobyproject.buildkit.worker.selinux.enabled:false org.mobyproject.buildkit.worker.snapshotter:windows], platforms=[windows/amd64]"
# time="2024-02-26T10:42:16+03:00" level=info msg="found 1 workers, default=\"zcy8j5dyjn3gztjv6gv9kn037\""
# time="2024-02-26T10:42:16+03:00" level=warning msg="currently, only the default worker can be used."
# time="2024-02-26T10:42:16+03:00" level=info msg="running server on //./pipe/buildkitd"

# Running buildkitd with the CNI:

# Note that the above simple run will not have the networking bit setup; for instance you won't be able to access the internet from the builds e.g. downloading resources.

# Follow the instructions in the CNI / Networking Setup section. Once that is done, you can now start buildkitd providing the binary and config paths to the flags. These are the same paths used by containerd too:

# buildkitd `
#     --containerd-cni-config-path="C:\Program Files\containerd\cni\conf\0-containerd-nat.conf" `
#     --containerd-cni-binary-dir="C:\Program Files\containerd\cni\bin"

#     NOTE: the above CNI paths are now set by default, you can now just run buildkitd.

# You can also run buildkitd as a Windows Service:

# buildkitd `
#     --register-service `
#     --service-name buildkitd `
#     --containerd-cni-config-path="C:\Program Files\containerd\cni\conf\0-containerd-nat.conf" `
#     --containerd-cni-binary-dir="C:\Program Files\containerd\cni\bin" `
#     --debug `
#     --log-file="C:\Windows\Temp\buildkitd.log"

#     NOTE: the above log-file path is just an example, but make sure to set up your logs properly.


## start-buildkit-with-cni-as-service.ps1

## From https://github.com/moby/buildkit/blob/c8178843b73773f1703bd73f5101041da4506157/docs/windows.md#setup-instructions

buildkitd `
    --register-service `
    --service-name buildkitd `
    --containerd-cni-config-path="C:\Program Files\containerd\cni\conf\0-containerd-nat.conf" `
    --containerd-cni-binary-dir="C:\Program Files\containerd\cni\bin" `
    --debug `
    --log-file="C:\Windows\Temp\buildkitd.log"

# buildkitd on Windows depends on containerd. You can make the above registered buildkitd service dependent on containerd (the naming may vary). The space after = is required:
sc.exe config buildkitd depend= containerd

# We can also set the service to start automatically:
Set-Service -StartupType Automatic buildkitd


# buildkitd on Windows depends on containerd. You can make the above registered buildkitd service dependent on containerd (the naming may vary). The space after = is required:

# sc.exe config buildkitd depend= containerd

# We can also set the service to start automatically:

# Set-Service -StartupType Automatic buildkitd

# In another terminal (still elevated), try out a buildctl command to test that the setup is good:

# PS> buildctl debug info
# BuildKit: github.com/moby/buildkit v0.0.0+unknown

#     NOTE: the version is v0.0.0+unknown since this is still a release candidate (RC).

