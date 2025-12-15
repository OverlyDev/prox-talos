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

  scripts.contexts.exec = ''
    echo "Kubernetes contexts:"
    kubectl config get-contexts -o name
    echo ""
    echo "Talos contexts:"
    talosctl config contexts
  '';

  scripts.use-context.exec = ''
    set -e

    if [ $# -ne 1 ]; then
        echo "Usage: use-context <environment>"
        echo ""
        echo "Examples:"
        echo "  use-context staging"
        echo "  use-context prod"
        echo ""
        echo "Available contexts:"
        contexts
        exit 1
    fi

    ENV=$1

    # Find matching kubectl context (fuzzy match)
    KUBE_CONTEXT=$(kubectl config get-contexts -o name | grep -i "$ENV" | head -n 1)

    if [ -z "$KUBE_CONTEXT" ]; then
        echo "No kubectl context found matching: $ENV"
        echo ""
        echo "Available kubectl contexts:"
        kubectl config get-contexts -o name
        exit 1
    fi

    # Find matching talos context (fuzzy match)
    # talosctl outputs a table, so we need to skip the header and extract the NAME column
    TALOS_CONTEXT=$(talosctl config contexts 2>/dev/null | tail -n +2 | awk '{print $2}' | grep -i "$ENV" | head -n 1)

    if [ -z "$TALOS_CONTEXT" ]; then
        echo "Warning: No talos context found matching: $ENV (kubectl context will still be set)"
        kubectl config use-context "$KUBE_CONTEXT"
        echo "✓ Switched kubectl to: $KUBE_CONTEXT"
        exit 0
    fi

    # Set both contexts
    kubectl config use-context "$KUBE_CONTEXT" > /dev/null
    talosctl config context "$TALOS_CONTEXT"

    echo "✓ Switched to $ENV environment:"
    echo "  kubectl context: $KUBE_CONTEXT"
    echo "  talos context:   $TALOS_CONTEXT"
  '';
}
