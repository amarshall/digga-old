{ lib, nixos-generators }:
{
  customBuilds =
    { lib, pkgs, config, baseModules, modules, ... }@args:
    {
      # created in modules system for access to specialArgs and modules
      lib.digga.mkBuild = buildModule:
        import "${toString pkgs.path}/nixos/lib/eval-config.nix" {
          inherit (pkgs) system;
          inherit baseModules;
          modules = modules ++ [ buildModule ];
          # Newer versions of module system pass specialArgs to modules
          # so try to pass that to eval if possible.
          specialArgs = args.specialArgs or { };
        };
      system.build =
        let
          builds = lib.mapAttrs
            (format: module:
              let build = config.lib.digga.mkBuild module; in
              build // build.config.system.build.${build.config.formatAttr}
            )
            nixos-generators.nixosModules;
        in
        # ensure these builds can be overriden by other modules
        lib.mkBefore builds;
    };

  hmNixosDefaults = { specialArgs, modules }:
    { options, ... }: {
      config = lib.optionalAttrs (options ? home-manager) {
        home-manager = {
          # always use the system nixpkgs from the host's channel
          useGlobalPkgs = true;
          # and use the possible future default (see manual)
          # mkForce so that deploy-rs' profilePath is well-known
          useUserPackages = lib.mkForce true;

          extraSpecialArgs = specialArgs;
          sharedModules = modules;
        };
      };
    };

  globalDefaults = { self, hmUsers }:
    { config, pkgs, ... }: {
      users.mutableUsers = lib.mkDefault false;

      hardware.enableRedistributableFirmware = lib.mkDefault true;

      # digga lib can be accessed in modules directly as config.lib.digga
      lib = {
        inherit (pkgs.lib) digga;
      };

      _module.args = {
        inherit self hmUsers;
        hosts = builtins.mapAttrs (_: host: host.config)
          (removeAttrs self.nixosConfigurations [ config.networking.hostName ]);
      };

      system.configurationRevision = lib.mkIf (self ? rev) self.rev;
    };
}

