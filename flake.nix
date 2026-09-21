{
  description = "NixOS Ollama Devstral CUDA appliance";

  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [ "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=" ];
  };

  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";

    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";

    set-and-setting.url = "github:pr0d1r2/set-and-setting";
    set-and-setting.inputs.nixpkgs-lock.follows = "nixpkgs-lock";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-generators,
      set-and-setting,
      ...
    }:
    let
      nvidiaModule =
        { config, ... }:
        {
          hardware.graphics.enable = true;
          hardware.opengl.enable = true;
          hardware.nvidia = {
            modesetting.enable = true;
            open = false;
            nvidiaSettings = false;
            package = config.boot.kernelPackages.nvidiaPackages.stable;
          };
          services.xserver.videoDrivers = [ "nvidia" ];
        };
    in
    set-and-setting.lib.mkConsumerFlake {
      inherit self set-and-setting nixpkgs;
      extraPackages =
        pkgs:
        nixpkgs.lib.optionalAttrs (pkgs.system == "x86_64-linux") {
          iso = nixos-generators.nixosGenerate {
            system = "x86_64-linux";
            format = "iso";
            modules = [
              nvidiaModule
              {
                nixpkgs.config = {
                  allowUnfree = true;
                  cudaSupport = true;
                };
              }
              {
                system.stateVersion = "26.05";
                fileSystems."/" = {
                  device = "none";
                  fsType = "tmpfs";
                };
                boot.loader.grub.devices = [ "nodev" ];
              }
            ];
          };
        };
      fragments = [
        "base"
        "actions"
        "nix"
        "shell"
        "ascii"
        "markdown"
        "yaml"
      ];
      src = ./.;
    }
    // {
      nixosConfigurations.devstral = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nvidiaModule
          {
            nixpkgs.config = {
              allowUnfree = true;
              cudaSupport = true;
            };
          }
          {
            system.stateVersion = "26.05";
            fileSystems."/" = {
              device = "none";
              fsType = "tmpfs";
            };
            boot.loader.grub.devices = [ "nodev" ];
          }
        ];
      };
    };
}
