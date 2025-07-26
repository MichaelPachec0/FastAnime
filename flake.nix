{
  description = "FastAnime Project Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };

      python = pkgs.python312;
      pyShortVersion = "cp${builtins.replaceStrings [ "." ] [ "" ] python.pythonVersion}";
      platforms = {
        # TODO: TRY AND FIX THIS?

        # aarch64-darwin = {
        #   platform = "macosx_15_0_arm64" ;
        #   hash = pkgs.lib.fakeHash;
        # };
        #
        # aarch64-linux =  { 
        #   platform = "manylinux_2_17_aarch64.manylinux2014_aarch64";
        #   hash = pkgs.lib.fakeHash;
        # };
        # x86_64-darwin = { 
        #   platform = "macosx_15_0_x86_64";
        #   hash = pkgs.lib.fakeHash;
        # };
        x86_64-linux = {
          platform = "manylinux_2_17_x86_64.manylinux2014_x86_64";
          hash = "sha256-+/RBhHGpYVjZlcRXNpfOLc8nykLQsDw7+XsBZQFb9kE=";
        };
      };
      platform = platforms.${pkgs.system}.platform or (throw "Unsupported system: ${pkgs.system}");
      hash = platforms.${pkgs.system}.hash;
      
      libtorrent = python.pkgs.buildPythonPackage rec {
        pname = "libtorrent";
        version = "2.0.11";
        format = "wheel";

        src = pkgs.fetchPypi {
          inherit pname version format platform hash;
          dist = pyShortVersion;
          python = pyShortVersion;
          abi = pyShortVersion;
        };
      };
      pythonPackages = python.pkgs;
      fastanimeEnv = pythonPackages.buildPythonApplication {
        pname = "fastanime";
        version = "2.9.9";

        src = self;

        preBuild = ''
          sed -i 's/rich>=13.9.2/rich>=13.8.1/' pyproject.toml
          sed -i 's/pycryptodome>=3.21.0/pycryptodome>=3.20.0/' pyproject.toml
          sed -i 's/pydantic>=2.11.7/pydantic>=2.11.4/' pyproject.toml
          sed -i 's/lxml>=6.0.0/lxml>=5.4.0/' pyproject.toml
        '';

        # Add runtime dependencies
        propagatedBuildInputs = with pythonPackages; [
          click
          inquirerpy
          requests
          rich
          thefuzz
          yt-dlp
          dbus-python
          hatchling
          plyer
          mpv
          fastapi
          pycryptodome
          pypresence
          beautifulsoup4
          httpx
          libtorrent
          lxml
        ] ++ (with pkgs; [
            fzf
          ]);

        # Ensure compatibility with the pyproject.toml
        format = "pyproject";
      };

    in
    {
      packages.default = fastanimeEnv;

      # DevShell for development
      devShells.default = pkgs.mkShell {
        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.libxcrypt-legacy ];
        buildInputs = [
          fastanimeEnv
          pythonPackages.hatchling
          pkgs.mpv
          pkgs.fzf
          pkgs.rofi
          pkgs.uv
          pkgs.pyright
        ];
        shellHook = ''
          uv venv -q
          source ./.venv/bin/activate
        '';
      };
    });
}
