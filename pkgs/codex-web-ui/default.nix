#
# The codexapp npm tarball does not ship a package-lock.json.
# The lock file below is generated to keep buildNpmPackage reproducible.
#
# When upgrading to a new version:
#
#   1. Download and extract the tarball:
#
#        VERSION=0.1.87
#        curl -L -o /tmp/codexapp-${VERSION}.tgz \
#          https://registry.npmjs.org/codexapp/-/codexapp-${VERSION}.tgz
#        mkdir -p /tmp/codexapp
#        tar -xf /tmp/codexapp-${VERSION}.tgz -C /tmp/codexapp
#
#   2. Generate the lock file (--ignore-scripts avoids native builds):
#
#        cd /tmp/codexapp/package
#        npm install --package-lock-only --ignore-scripts
#
#   3. Copy the lock file into this directory:
#
#        cp /tmp/codexapp/package/package-lock.json pkgs/codexui/package-lock.json
#
#   4. Update the source hash:
#
#        nix hash file --sri /tmp/codexapp-${VERSION}.tgz
#
#   5. Update npmDepsHash:
#
#        nix build nixpkgs#prefetch-npm-deps -o /tmp/prefetch-npm-deps
#        /tmp/prefetch-npm-deps/bin/prefetch-npm-deps pkgs/codexui/package-lock.json
#
#   6. Replace the version, hash, and npmDepsHash values below.
{
  lib,
  buildNpmPackage,
  fetchurl,
  python3,
  pkg-config,
  makeWrapper,
  codex,
}:

let
  pname = "codexapp";
  version = "0.1.87";
  packageLock = ./package-lock.json;
in
buildNpmPackage {
  inherit pname version;

  src = fetchurl {
    url = "https://registry.npmjs.org/codexapp/-/codexapp-${version}.tgz";
    hash = "sha256-wwhdXVaalMBv92rVgZBLdl92EdqoTpSRtMleq2HUnMY=";
  };

  sourceRoot = "package";

  npmDepsHash = "sha256-C7G8heYtHjkPk8izHkkcD9tmmwncoLV5o7GGTIKTPoI=";

  postPatch = ''
    cp ${packageLock} package-lock.json
  '';

  nativeBuildInputs = [
    python3
    pkg-config
    makeWrapper
  ];

  postInstall = ''
    wrapProgram "$out/bin/codexui" \
      --prefix PATH : "${lib.makeBinPath [ codex ]}" \
      --set CODEX_CLI_PATH "${codex}/bin/codex" \
      --set CUSTOM_CLI_PATH "${codex}/bin/codex" \
  '';

  npmFlags = [ "--omit=dev" ];
  dontNpmBuild = true;

  meta = with lib; {
    description = "Web interface for Codex app-server";
    homepage = "https://github.com/friuns2/codexui";
    license = licenses.mit;
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "codexui";
  };
}
