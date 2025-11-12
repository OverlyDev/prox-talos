{ pkgs, lib, config, inputs, ... }:

let
  # List of packages to install and test
  myPackages = [
    pkgs.git
    pkgs.talosctl
    pkgs.kubectl
    pkgs.kubernetes-helm
    pkgs.k9s
  ];
in
{
  packages = myPackages;

  languages.terraform.enable = true;

  env = {
    PATH = "$DEVENV_PROFILE/bin:$PATH";
    TALOSCONFIG = "${config.devenv.root}/talosconfig";
    KUBECONFIG = "${config.devenv.root}/kubeconfig";
  };

  processes.code.exec = "code .";

  # Arguments:
  #   $1 - the executable
  #   $2 - expected version
  #   $3 - version command (default --version)
  scripts.checkPkgVersion.exec = ''
    eval "$1 ''${3:---version}" 2>/dev/null | grep -q "$2" && echo "$1: $2" || (echo "Missing $1 version: $2" && exit 1)
  '';

  enterTest = ''
    echo "Running tests"
    checkPkgVersion "${pkgs.git.meta.mainProgram}" "${pkgs.git.version}"
    checkPkgVersion "${pkgs.terraform.meta.mainProgram}" "${pkgs.terraform.version}"
    checkPkgVersion talosctl "${pkgs.talosctl.version}" "version --short"
    checkPkgVersion kubectl "${pkgs.kubectl.version}" 'version --client'
    checkPkgVersion helm "${pkgs.kubernetes-helm.version}" "version --short"
    checkPkgVersion k9s "${pkgs.k9s.version}" "version --short"
  '';

  enterShell = ''
    terraform --version | head -n 1
    terraform init
  '';

}
