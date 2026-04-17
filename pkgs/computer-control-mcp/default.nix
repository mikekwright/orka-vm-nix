{
  lib,
  fetchurl,
  python3Packages,
  makeWrapper,
  stdenv,
  xclip,
  xdotool,
  wmctrl,
  scrot,
  xprop,
  xrandr,
}:

let
  pyautogui = python3Packages.pyautogui.overrideAttrs (_: {
    doInstallCheck = false;
    installCheckPhase = ":";
  });
in
python3Packages.buildPythonApplication rec {
  pname = "computer-control-mcp";
  version = "0.3.10";
  pyproject = true;

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/source/c/computer-control-mcp/computer_control_mcp-${version}.tar.gz";
    hash = "sha256-yrusGXwIwBspmmROD+wwSkriRVxwznW6MNAClWRpB44=";
  };

  nativeBuildInputs = with python3Packages; [
    hatchling
    pythonRelaxDepsHook
    makeWrapper
  ];

  pythonRelaxDeps = [
    "fuzzywuzzy"
    "mcp"
    "mss"
    "onnxruntime"
    "opencv-python"
    "pillow"
    "pyautogui"
    "pygetwindow"
    "python-Levenshtein"
    "pywinctl"
    "rapidocr"
    "rapidocr_onnxruntime"
  ];

  pythonRemoveDeps = [
    "windows-capture"
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [ "pywinctl" ];

  propagatedBuildInputs =
    with python3Packages;
    [
      fuzzywuzzy
      mcp
      mss
      onnxruntime
      opencv4
      pillow
      pyautogui
      pygetwindow
      levenshtein
      rapidocr
      python3Packages."rapidocr-onnxruntime"
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ pywinctl ];

  dontCheckRuntimeDeps = true;

  postFixup =
    let
      runtimePath = lib.makeBinPath (
        lib.optionals stdenv.hostPlatform.isLinux [
          scrot
          wmctrl
          xclip
          xdotool
          xprop
          xrandr
        ]
      );
    in
    ''
      for program in $out/bin/computer-control-mcp $out/bin/computer-control-mcp-server; do
        wrapProgram "$program" --prefix PATH : "${runtimePath}"
      done
    '';

  meta = with lib; {
    description = "MCP server for desktop mouse, keyboard, and OCR control";
    homepage = "https://github.com/AB498/computer-control-mcp";
    license = licenses.mit;
    mainProgram = "computer-control-mcp";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
