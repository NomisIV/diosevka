{
  description = "My custom build of Iosevka";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs;
    flake-utils.url = github:numtide/flake-utils;
    npmlock2nix = {
      url = github:tweag/npmlock2nix;
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, npmlock2nix }:
    flake-utils.lib.eachDefaultSystem ( system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";
        npm = pkgs.callPackage (npmlock2nix + "/internal.nix") { };

        version = "v11.0.1";

        build_plan = ./. + "/build-plan-${version}.toml";

        iosevka = pkgs.fetchFromGitHub {
          owner = "be5invis";
          repo = "Iosevka";
          rev = version;
          sha256 = "sha256-yGLvXTvxHBvFpyuXHpUaT8rAHXP8jiGgBLQoeBXDp60=";
        };

        diosevka = font_type: npm.build {
          src = iosevka;
          buildInputs = with pkgs; [ ttfautohint-nox ];

          configurePhase = ''
            runHook preConfigure
            cp "${build_plan}" private-build-plans.toml
            runHook postConfigure
          '';

          buildCommands = [ "npm run build -- ${font_type}::diosevka" ];

          installPhase = ''
            runHook preInstall
            mkdir -p $out/share/fonts/diosevka
            cp -r dist/diosevka/${font_type} $out/share/fonts/diosevka
            runHook postInstall
          '';
        };
      in rec {
        packages = {
          all = diosevka "contents";
          ttf = diosevka "ttf";
          ttf-unhinted = diosevka "ttf-unhinted";
          woff2 = diosevka "woff2";
        };
        defaultPackage = packages.ttf;
        legacyPackages = packages;
      }
    );
}
