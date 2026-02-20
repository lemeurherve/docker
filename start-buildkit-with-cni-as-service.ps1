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

