{ lib, ... }:
let
  versionInfo = builtins.fromJSON (builtins.readFile ../VERSION.json);
in
{
  perSystem =
    { pkgs, ... }:
    let
      pname = "pi-slopchop";
      packageName = "pi-slopchop";
      packagePath = "lib/node_modules/${packageName}";
      slopchop = pkgs.buildNpmPackage {
        inherit pname;
        version = versionInfo.version;

        src = pkgs.fetchFromGitHub {
          owner = "robzolkos";
          repo = "pi-slopchop";
          tag = "v${versionInfo.version}";
          hash = versionInfo.srcHash;
        };

        npmDepsHash = versionInfo.npmDepsHash;
        patches = [
          ../patches/infer-review-repo-from-session-files.patch
          ../patches/default-side-by-side-wrapped-diff.patch
        ];
        nodejs = pkgs.nodejs_22;

        dontNpmBuild = true;

        doCheck = true;
        nativeCheckInputs = [ pkgs.git ];
        checkPhase = ''
          runHook preCheck
          npm run typecheck
          npm test
          runHook postCheck
        '';

        doInstallCheck = true;
        nativeInstallCheckInputs = [ pkgs.nodejs_22 ];
        installCheckPhase = ''
          runHook preInstallCheck
          pkg="$out/${packagePath}"
          test -f "$pkg/package.json"
          test -f "$pkg/src/index.ts"
          node - "$pkg/package.json" "${versionInfo.version}" <<'NODE'
          const fs = require("fs");
          const [manifestPath, expectedVersion] = process.argv.slice(2);
          const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
          if (manifest.name !== "pi-slopchop") throw new Error(`unexpected package name: ''${manifest.name}`);
          if (manifest.version !== expectedVersion) throw new Error(`unexpected version: ''${manifest.version}`);
          if (!Array.isArray(manifest.pi?.extensions) || !manifest.pi.extensions.includes("./src/index.ts")) {
            throw new Error("missing Pi extension metadata for ./src/index.ts");
          }
          NODE
          runHook postInstallCheck
        '';

        passthru.packagePath = "${placeholder "out"}/${packagePath}";

        meta = {
          description = "Terminal-native code review and annotation workflow for the Pi coding agent";
          homepage = "https://github.com/robzolkos/pi-slopchop";
          license = lib.licenses.mit;
          platforms = [
            "aarch64-darwin"
            "x86_64-linux"
          ];
        };
      };
      slopchopWithPassthru = slopchop.overrideAttrs (old: {
        passthru = (old.passthru or { }) // {
          packagePath = "${slopchop}/${packagePath}";
        };
      });
    in
    {
      packages.pi-slopchop = slopchopWithPassthru;
      packages.default = slopchopWithPassthru;
    };
}
