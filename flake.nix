{
  description = "Noise Socket library in OCaml";

  # we're using this commit since the required dependencies aren't in master yet
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/5d74941c45cdb8d4a180d19642049aaec14f325d";
  inputs.nixpkgs-angstrom = { url = "github:NixOS/nixpkgs/51d90811235cb5557e76f5d9665cd3337bc82e53"; flake = false; };

  inputs.flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "armv7l-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      supportedOcamlPackages = [
        "ocamlPackages_4_10"
        "ocamlPackages_4_11"
        "ocamlPackages_4_12"
      ];
      defaultOcamlPackages = "ocamlPackages_4_12";

      forAllOcamlPackages = nixpkgs.lib.genAttrs supportedOcamlPackages;
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor =
        forAllSystems (
          system:
            import nixpkgs {
              inherit system;
              overlays = [ self.overlay ];
            }
        );
    in
      {
        overlay = final: prev:
          with final;
          let
            mkOcamlPackages = prevOcamlPackages:
              with prevOcamlPackages;
              let
                ocamlPackages = {
                  inherit buildDunePackage lwt noise ounit stdint;
                  inherit alcotest;
                  inherit ocaml;
                  inherit findlib;
                  inherit ocamlbuild;
                  inherit opam-file-format;

                  # ugly IFD because we need older angstrom
                  inherit ((import inputs.nixpkgs-angstrom { system = "x86_64-linux"; }).pkgs.ocamlPackages) angstrom;

                  noise-socket =
                    buildDunePackage rec {
                      pname = "noise-socket";
                      version = "0.0.1";
                      src = self;

                      useDune2 = true;

                      nativeBuildInputs = with ocamlPackages; [ odoc ];

                      propagatedBuildInputs = with ocamlPackages; [
                        angstrom
                        noise
                        stdint
                      ];

                      doCheck = true;
                      checkInputs = [
                        lwt
                        ounit
                      ];
                    };
                };
              in
                ocamlPackages;
          in
            let
              allOcamlPackages =
                forAllOcamlPackages (
                  ocamlPackages:
                    mkOcamlPackages ocaml-ng.${ocamlPackages}
                );
            in
              allOcamlPackages // {
                ocamlPackages = allOcamlPackages.${defaultOcamlPackages};
              };

        devShell.x86_64-linux = nixpkgsFor.x86_64-linux.ocamlPackages.noise-socket;
          #let
          #  pkgs = nixpkgs.legacyPackages.x86_64-linux;
          #in
          #  pkgs.mkShell {
          #    packages = with pkgs; [ opam pkgconfig gcc gnumake gmp solo5 ocamlPackages.dune_2 ocamlPackages.ocaml ];
          #  };

        packages =
          forAllSystems (
            system:
              forAllOcamlPackages (
                ocamlPackages:
                  nixpkgsFor.${system}.${ocamlPackages}
              )
          );

        defaultPackage =
          forAllSystems (
            system:
              nixpkgsFor.${system}.ocamlPackages.noise-socket
          );
      };
}
