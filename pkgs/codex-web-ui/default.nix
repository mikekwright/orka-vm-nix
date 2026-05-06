{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  bash,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "codex-web-ui";
  version = "0.1.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/codex-web-ui/-/codex-web-ui-${finalAttrs.version}.tgz";
    hash = "sha512-TgdYctHtQdpqTg2Og+gVQrfKUWR6SKvonvwbbtbPfmMLZEI+mL/m3ihESjCA3BrzBevoIKJjF+/0P9YpBXo9Ew==";
  };

  nativeBuildInputs = [ makeWrapper ];

  unpackPhase = ''
    runHook preUnpack
    tar -xzf "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/share/codex-web-ui"
    cp -R package/* "$out/share/codex-web-ui/"
    cp ${./launch_codex_webui_unpacked.sh} "$out/share/codex-web-ui/launch_codex_webui_unpacked.sh"
    patchShebangs "$out/share/codex-web-ui"

    makeWrapper "${bash}/bin/bash" "$out/bin/codex-web-ui" \
      --add-flags "$out/share/codex-web-ui/launch_codex_webui_unpacked.sh"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Launch Codex Desktop Web UI from the command line";
    homepage = "https://www.npmjs.com/package/codex-web-ui";
    license = licenses.mit;
    platforms = platforms.darwin ++ platforms.linux;
    mainProgram = "codex-web-ui";
  };
})
