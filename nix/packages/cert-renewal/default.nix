{
  writeShellApplication,
  curl,
  openssl,
  ...
}:
writeShellApplication {
  name = "cert-renewal";
  runtimeInputs = [
    curl
    openssl
  ];
  text = builtins.readFile ./cert-renewal.sh;
}
