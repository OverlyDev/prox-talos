{ pkgs, lib, config, inputs, ... }:

{
  packages = [ pkgs.git ];

  languages.terraform.enable = true;

  env = {
    PATH = "$DEVENV_PROFILE/bin:$PATH";
  };

  processes.code.exec = "code .";

  # Arguments:
  #   $1 - the executable
  #   $2 - expected version
  #   #3 - version command (default --version)
  scripts.checkPkgVersion.exec = ''
    $1 ''${3:---version} | grep -q "$2" && echo "$1: $2" || (echo "Missing $1 version: $2" && exit 1)
  '';

  enterTest = ''
    echo "Running tests"
    checkPkgVersion "${pkgs.git.meta.mainProgram}" "${pkgs.git.version}"
    checkPkgVersion "${pkgs.terraform.meta.mainProgram}" "${pkgs.terraform.version}"
  '';

  enterShell = ''
    terraform --version | head -n 1
    terraform init
  '';

}
