# A simple shell script which transforms one JSON file into another using
# a Nix function.
#
# The input JSON file is read from stdin.
# The output JSON file is written to stdout.
# The file containing the Nix function is passed as the first argument.
{ writeShellApplication,  nix, jq, inputs, ... }: writeShellApplication {
  name = "nix-render-template";
  runtimeInputs = [
    nix
    jq
  ];

  text = ''
    # shellcheck disable=SC1083
    nix --extra-experimental-features nix-command \
      eval \
        --json \
        --file "$1" \
        --apply 'let
            nixpkgs = import ${inputs.nixpkgs} {};
            stdin = builtins.readFile /dev/stdin;
          in f: f {
            lib = nixpkgs.lib;
            config = builtins.fromJSON stdin;
          }' \
    | jq
  '';
}
