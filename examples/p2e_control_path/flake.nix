{
  description = "P2E Control Path Build Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
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
        };
      }
    );
}
