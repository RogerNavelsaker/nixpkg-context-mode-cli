{
  bun,
  bun2nix,
  fetchFromGitHub,
  lib,
  makeWrapper,
  stdenv,
}:

let
  manifest = builtins.fromJSON (builtins.readFile ./package-manifest.json);
  upstreamSrc = fetchFromGitHub {
    owner = manifest.upstream.owner;
    repo = manifest.upstream.repo;
    rev = manifest.upstream.rev;
    hash = manifest.upstream.hash;
  };
  licenseMap = {
    "Elastic-2.0" = lib.licenses.elastic20;
  };
  resolvedLicense =
    if builtins.hasAttr manifest.meta.licenseSpdx licenseMap
    then licenseMap.${manifest.meta.licenseSpdx}
    else lib.licenses.unfree;
in
stdenv.mkDerivation {
  pname = manifest.binary.name;
  version = manifest.package.version or manifest.upstream.version;
  src = upstreamSrc;

  nativeBuildInputs = [
    bun
    bun2nix.hook
    makeWrapper
  ];

  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ../bun.nix;
  };

  dontRunLifecycleScripts = true;
  bunInstallFlags =
    if stdenv.hostPlatform.isDarwin
    then [
      "--linker=hoisted"
      "--backend=copyfile"
    ]
    else [
      "--linker=hoisted"
    ];

  postPatch = ''
    cp ${../bun.lock} bun.lock
  '';
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    shareRoot="$out/share/${manifest.binary.name}"
    mkdir -p "$shareRoot"
    cp \
      .mcp.json \
      README.md \
      bun.lock \
      package.json \
      "$shareRoot"/
    cp -R \
      bin \
      scripts \
      "$shareRoot"/

    mkdir -p "$out/bin"
    makeWrapper ${lib.getExe' bun "bun"} "$out/bin/${manifest.binary.name}" \
      --prefix PATH : ${lib.makeBinPath [ bun ]} \
      --add-flags "$shareRoot/${manifest.binary.entrypoint}"

    runHook postInstall
  '';

  meta = with lib; {
    description = manifest.meta.description;
    homepage = manifest.meta.homepage;
    license = resolvedLicense;
    mainProgram = manifest.binary.name;
    platforms = platforms.linux ++ platforms.darwin;
    broken = manifest.stubbed || !(builtins.pathExists ../bun.nix);
  };
}
