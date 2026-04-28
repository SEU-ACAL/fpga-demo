{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "p2e-control-path-build";

  buildInputs = with pkgs; [
    cmake
    gcc
    gnumake
  ];

  shellHook = ''
    echo "P2E Control Path Build Environment"
    echo "CMake version: $(cmake --version | head -1)"
    echo "GCC version: $(gcc --version | head -1)"

    # Source HPEC environment
    if [ -f "$PWD/sourceme.sh" ]; then
      source "$PWD/sourceme.sh"
    fi
  '';
}
