HTTPBASE = "http://orion-cli.orion.altus.bblabs.rim.net/~chef/context"
#NAME = "bbuczynski-driver-test2"
NAME = "bbuczynski-test-vm"
MEMORY = 4096
CPU = 1
VCPU = 1
OS = [
  ARCH = x86_64
]
DISK = [
  IMAGE = "Ubuntu-12.04.5-pre-prod-20141216",
  IMAGE_UNAME = m_plumb,
  DRIVER = qcow2
]
DISK=[
  IMAGE="bbuczynski-test-img",
  IMAGE_UNAME="bbsl-auto"
]
NIC = [
  NETWORK = "PUB-52-10.236",
  NETWORK_UNAME = "neutrino"
]
GRAPHICS = [
  LISTEN = "0.0.0.0",
  TYPE = vnc
]
CONTEXT = [
  NETWORK = "YES",
  HOSTNAME" = "$NAME",
  INSTALL_CHEF_CLIENT_COMMAND = "dpkg -E -i /mnt/chef-client.deb",
  SSH_USER = "local",
  SSH_PUBLIC_KEY = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAIEAgaA3GDtH38JPk7fh6s7pvX6BBcyLkgF7Wf/Le0zeEWqhv+LdM/m308ysFViGDrgqMQYFkSWrLW79XfDlYXVIlVcFzdQEj3tloFn3xOi5q5oVEqVxorXLaiZ5AIA8tG+1ENLHsA1zb57ECVJrMRhPdtYUDMtmoNJOapZJSkF+ihc= rsa-key-20150220",
  FILES = "$HTTPBASE/01_chef $HTTPBASE/../chef-client.deb"
]