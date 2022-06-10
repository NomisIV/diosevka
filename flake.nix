{
  description = "My custom build of Iosevka";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    npmlock2nix = {
      url = "github:nix-community/npmlock2nix";
      flake = false;
    };
  };

  outputs = inputs:
    with inputs;
      flake-utils.lib.eachDefaultSystem (system: let
        pkgs = nixpkgs.legacyPackages."${system}";

        otf2bdf = pkgs.stdenv.mkDerivation rec {
          name = "otf2bdf";
          version = "v3.1";

          src = pkgs.fetchFromGitHub {
            owner = "jirutka";
            repo = name;
            rev = version;
            sha256 = "sha256-HK9ZrnwKhhYcBvSl+3RwFD7m/WSaPkGKX6utXnk5k+A=";
          };

          buildInputs = with pkgs; [freetype];

          buildPhase = ''
            make otf2bdf
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp otf2bdf $out/bin/
          '';
        };

        npm = pkgs.callPackage (npmlock2nix + "/default.nix") {};

        version = "v15.2.0";

        buildPlan = ./. + "/build-plan-${version}.toml";

        iosevka = pkgs.fetchFromGitHub {
          owner = "be5invis";
          repo = "Iosevka";
          rev = version;
          sha256 = "sha256-B6BM9z2ndA//rExinKEMjraApFk/39JsbPH0+N5pOpo=";
        };

        diosevka = fontType:
          npm.build {
            pname = "diosevka-${fontType}";
            version = version;
            src = iosevka;
            buildInputs = with pkgs; [ttfautohint-nox];

            configurePhase = ''
              runHook preConfigure
              cp "${buildPlan}" private-build-plans.toml
              runHook postConfigure
            '';

            buildCommands = ["npm run build -- ${fontType}::diosevka"];

            installPhase = ''
              runHook preInstall
              mkdir -p $out/share/fonts/diosevka
              cp -r dist/diosevka/${fontType} $out/share/fonts/diosevka
              runHook postInstall
            '';
          };

        diosevkaBdf = size:
          pkgs.stdenvNoCC.mkDerivation {
            pname = "diosevka-bdf";
            version = version;
            buildInputs = [otf2bdf];
            src = diosevka "ttf-unhinted";
            buildPhase = ''
              otf2bdf \
                -p ${toString size} \
                -rh 96 \
                -rv 95 \
                -o diosevka.bdf \
                share/fonts/diosevka/ttf-unhinted/diosevka-regular.ttf \
                || echo ""
            '';
            installPhase = ''
              mkdir -p $out/share/fonts/diosevka/bdf
              cp -r diosevka.bdf $out/share/fonts/diosevka/bdf/
            '';
          };

        diosevkaPsf = size:
          pkgs.stdenvNoCC.mkDerivation {
            pname = "diosevka-psf";
            version = version;
            buildInputs = with pkgs; [bdf2psf];
            src = diosevkaBdf size;

            patchPhase = ''
              # Round the average width
              bdf="share/fonts/diosevka/bdf/diosevka.bdf"
              width="$(grep AVERAGE_WIDTH $bdf | cut -d ' ' -f 2)"
              width="$(( (((width - 1) / 10) + 2) * 10))"
              sed -i "s/AVERAGE_WIDTH .*/AVERAGE_WIDTH $width/" $bdf
            '';

            buildPhase = ''
              bdf2psf --fb \
                share/fonts/diosevka/bdf/diosevka.bdf \
                ${pkgs.bdf2psf}/share/bdf2psf/standard.equivalents \
                ${pkgs.bdf2psf}/share/bdf2psf/fontsets/Uni2.512 \
                512 \
                diosevka.psf
            '';

            installPhase = ''
              mkdir -p $out/share/fonts/diosevka/psf
              cp -r diosevka.psf $out/share/fonts/diosevka/psf
            '';
          };
      in rec {
        packages = {
          default = diosevka "ttf";

          ttf = diosevka "ttf";
          ttf-unhinted = diosevka "ttf-unhinted";
          woff2 = diosevka "woff2";

          bdf = diosevkaBdf 12;
          psf = diosevkaPsf 12;
          bdf-large = diosevkaBdf 18;
          psf-large = diosevkaPsf 18;

          otf2bdf = otf2bdf;
        };

        formatter = pkgs.alejandra;
      });
}
