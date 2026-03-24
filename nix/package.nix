{
  bun,
  bun2nix,
  lib,
  makeWrapper,
  stdenv,
}:

let
  manifest = builtins.fromJSON (builtins.readFile ./package-manifest.json);
  upstreamSrc = builtins.path {
    path = ../upstream;
    name = "${manifest.binary.name}-src";
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
  version = manifest.package.version or manifest.source.version;
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
      README.md \
      bun.lock \
      package.json \
      "$shareRoot"/
    cp -R \
      bin \
      src \
      "$shareRoot"/
    mkdir -p "$shareRoot/skill"
    cp ${../skill/SKILL.md} "$shareRoot/skill/SKILL.md"

    mkdir -p "$out/bin"
    ln -s ${lib.getExe' bun "bun"} "$out/bin/bun"
    cat > "$out/bin/${manifest.binary.name}" <<EOF
#!${stdenv.shell}
if [ "\$1" = "skill" ]; then
  cat "$shareRoot/skill/SKILL.md"
  exit 0
fi
exec ${lib.getExe' bun "bun"} "$shareRoot/${manifest.binary.entrypoint}" "\$@"
EOF
    chmod +x "$out/bin/${manifest.binary.name}"

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
