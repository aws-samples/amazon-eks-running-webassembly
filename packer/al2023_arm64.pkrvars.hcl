######## set this to your region ########
region = "aa-example-1"
#########################################
eks_version     = "1.29"
instance_type   = "c6g.large"
architecture    = "arm64"
ami_description = "Amazon EKS Kubernetes AMI based on AmazonLinux2023 OS"

ami_block_device_mappings = [
  {
    device_name = "/dev/xvda"
    volume_size = 40
  },
]

launch_block_device_mappings = [
  {
    device_name = "/dev/xvda"
    volume_size = 40
  }
]

shell_provisioner1 = {
  expect_disconnect = true
  scripts = [
    "scripts/wasm-runtimes.sh",
    "scripts/cleanup.sh"
  ]
  environment_vars = [
    "wasmedge_shim_download_url=https://github.com/containerd/runwasi/releases/download/containerd-shim-wasmedge%2Fv0.4.0/containerd-shim-wasmedge-aarch64.tar.gz",
    "spin_shim_download_url=https://github.com/deislabs/containerd-wasm-shims/releases/download/v0.11.1/containerd-wasm-shims-v2-spin-linux-aarch64.tar.gz"
  ]
}
