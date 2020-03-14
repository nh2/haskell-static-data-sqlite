with (import <nixpkgs> {});
let
  # Needs NUR from https://github.com/nix-community/NUR
  ghc = nur.repos.mpickering.ghc.ghc865; # Keep in sync with the GHC version defined by stack.yaml!
in
  haskell.lib.buildStackProject {
    inherit ghc;
    name = "myEnv";
    # System dependencies used at build-time go in here.
    nativeBuildInputs = [
    ];
    # System dependencies used at run-time go in here.
    buildInputs = [
    ];
  }
