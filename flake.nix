{
  inputs.nixpkgs.url = "nixpkgs/nixos-25.11";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
      };

      sdk = (pkgs.androidenv.composeAndroidPackages {
        platformVersions = [ "36" ];
        buildToolsVersions = [ "36.0.0" ];
        toolsVersion = null;
        includeCmake = false;
        includeNDK = false;
        includeEmulator = false;
        includeSystemImages = false;
      }).androidsdk;

      enter = pkgs.writeShellScript "android-fhs-enter" ''
        if [ "$#" -gt 0 ]; then
          exec "$@"
        fi
        exec bash -i
      '';

      fhs = pkgs.buildFHSEnv {
        name = "android-fhs";
        multiArch = false;
        targetPkgs = p: [
          p.zlib
          p.libcxx
        ];
        runScript = "${enter}";
        profile = ''
          export JAVA_HOME="${pkgs.jdk17.home}"
          export ANDROID_HOME="${sdk}/libexec/android-sdk"
          export ANDROID_SDK_ROOT="$ANDROID_HOME"
          export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/36.0.0:$PATH"
          export GRADLE_OPTS="''${GRADLE_OPTS:-} -Dorg.gradle.java.home=$JAVA_HOME -Dorg.gradle.project.org.gradle.java.installations.paths=${pkgs.jdk11.home},${pkgs.jdk17.home}"
        '';
      };
    in {
      packages.${system}.build = pkgs.writeShellApplication {
        name = "build";
        text = ''
          exec ${fhs}/bin/android-fhs bash ./gradlew --no-daemon --console=plain \
            :app:assembleDebug :app:assembleRelease "$@"
        '';
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [ fhs ];
        shellHook = ''
          if [[ $- == *i* ]]; then
            exec ${fhs}/bin/android-fhs
          fi
        '';
      };
    };
}
