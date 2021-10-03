{

  description = "A lightweight and flexible command-line JSON processor";
  inputs.nixpkgs.follows = "nix/nixpkgs";

  outputs = { self, nix, nixpkgs, ... }:
    let
      supportedSystems = ["x86_64-linux" "i686-linux" "aarch64-linux"];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems ( s: f s );
      version = ''0.1.${nixpkgs.lib.substring 0 8 self.lastModifiedDate}.${self.shortRev or "dirty"}'';
      jqDerivation =
        { lib
        , stdenv
        , fetchpatch
        , fetchFromGitHub
        , autoreconfHook
        , onigurumaSupport ? true
        , oniguruma
        }:

        stdenv.mkDerivation rec {
          pname = "jq";
          inherit version;
          #version = "1.6";
          src = self;

          #src = fetchFromGitHub {
          #  owner = "stedolan";
          #  repo = "jq";
          #  rev = "${pname}-${version}";
          #  hash = "sha256-CIE8vumQPGK+TFAncmpBijANpFALLTadOvkob0gVzro";
          #};

          #patches = [
          #  ( fetchpatch {
          #      name = "fix-tests-when-building-without-regex-supports.patch";
          #      url = "https://github.com/stedolan/jq/pull/2292/commits/" +
          #            "f6a69a6e52b68a92b816a28eb20719a3d0cb51ae.patch";
          #      sha256 = "pTM5FZ6hFs5Rdx+W2dICSS2lcoLY1Q//Lan3Hu8Gr58=";
          #    } )
          #];

          outputs = [ "bin" "doc" "man" "dev" "lib" "out" ];

          # Upstream script that writes the version that's eventually compiled
          # and printed in `jq --help` relies on a .git directory which our src
          # doesn't keep.
          preConfigure = ''
            echo "#!/bin/sh" > scripts/version
            echo "echo ${version}" >> scripts/version
            patchShebangs scripts/version
          '';

          # paranoid mode: make sure we never use vendored version of oniguruma
          # Note: it must be run after automake, or automake will complain
          preBuild = ''
            rm -r ./modules/oniguruma
          '';

          buildInputs = lib.optionals onigurumaSupport [ oniguruma ];
          nativeBuildInputs = [ autoreconfHook ];

          configureFlags = [
            "--bindir=\${bin}/bin"
            "--sbindir=\${bin}/bin"
            "--datadir=\${doc}/share"
            "--mandir=\${man}/share/man"
          ] ++ lib.optional ( ! onigurumaSupport ) "--with-oniguruma=no"
          # jq is linked to libjq:
          ++ lib.optional ( ! stdenv.isDarwin )
               "LDFLAGS=-Wl,-rpath,\\\${libdir}";

          doInstallCheck = true;
          installCheckTarget = "check";

          postInstallCheck = ''
            $bin/bin/jq --help >/dev/null
            $bin/bin/jq -r '.values[1]' <<< '{"values":["hello","world"]}' | grep '^world$' > /dev/null
          '';

          passthru = { inherit onigurumaSupport; };

          meta = with lib; {
            description = "A lightweight and flexible command-line JSON processor";
            license = licenses.mit;
            maintainers = with maintainers; [ raskin globin ];
            platforms = platforms.unix;
            downloadPage = "https://stedolan.github.io/jq/download/";
            updateWalker = true;
          };
        };
    in {
      overlay = final: prev: {
        jq = final.callPackage jqDerivation { };
      };
      defaultPackage = forAllSystems ( sys:
        ( import nixpkgs {
            inherit sys;
            overlays = [self.overlay nix.overlay];
          }
        ).jq );
      nixosModule = { pkgs, ... }: { nixpkgs.overlays = [self.overlay]; };
      nixosModules.jq = self.nixosModule;
    };


}
