{
  description = "NixOS Ollama Devstral CUDA appliance";

  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [
      "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM="
    ];
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
    set-and-setting.lib.mkConsumerFlake {
      inherit self set-and-setting nixpkgs;
      extraPackages =
        pkgs:
        nixpkgs.lib.optionalAttrs (pkgs.system == "x86_64-linux") {
          iso = nixos-generators.nixosGenerate {
            system = "x86_64-linux";
            format = "iso";
            modules = [
              {
                networking = {
                  hostName = "devstral";
                  domain = "local";
                  useDHCP = true;
                  firewall = {
                    # Ollama has no authentication or TLS.  Restrict both
                    # Ollama and mDNS to the trusted private LAN.
                    extraCommands = ''
                      iptables -A nixos-fw -s 192.168.0.0/16 -p tcp --dport 11434 -j nixos-fw-accept
                      iptables -A nixos-fw -s 192.168.0.0/16 -p udp --dport 5353 -j nixos-fw-accept
                    '';
                    extraStopCommands = ''
                      iptables -D nixos-fw -s 192.168.0.0/16 -p tcp --dport 11434 -j nixos-fw-accept || true
                      iptables -D nixos-fw -s 192.168.0.0/16 -p udp --dport 5353 -j nixos-fw-accept || true
                    '';
                  };
                };
                services.avahi = {
                  enable = true;
                  nssmdns4 = true;
                  publish.enable = true;
                  extraServiceFiles = {
                    ollama = ''
                      <?xml version="1.0" standalone="no"?>
                      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
                      <service-group>
                        <name replace-wildcards="yes">Ollama on %h</name>
                        <service>
                          <type>_ollama._tcp</type>
                          <port>11434</port>
                        </service>
                      </service-group>
                    '';
                    http = ''
                      <?xml version="1.0" standalone="no"?>
                      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
                      <service-group>
                        <name replace-wildcards="yes">HTTP on %h</name>
                        <service>
                          <type>_http._tcp</type>
                          <port>11434</port>
                        </service>
                      </service-group>
                    '';
                  };
                };
              }
              (
                { config, pkgs, ... }:
                {
                  services.ollama = {
                    enable = true;
                    package = pkgs.ollama-cuda;
                    host = "0.0.0.0";
                    port = 11434;
                    environmentVariables = {
                      OLLAMA_KEEP_ALIVE = "-1";
                      OLLAMA_NUM_PARALLEL = "1";
                    };
                    models = "${pkgs.runCommand "ollama-devstral-model" {
                      __noChroot = true;
                      nativeBuildInputs = [
                        pkgs.curl
                        pkgs.ollama-cuda
                      ];
                    } (builtins.readFile ./scripts/embed-devstral.sh)}";
                  };
                  systemd.services.ollama.serviceConfig.ExecStartPost = [
                    "${pkgs.curl}/bin/curl --fail --silent --show-error --retry 60 --retry-delay 1 --retry-connrefused -H 'Content-Type: application/json' -d '{\"model\":\"devstral\",\"prompt\":\"warm up\",\"stream\":false}' http://127.0.0.1:11434/api/generate --output /dev/null"
                  ];
                  hardware = {
                    graphics.enable = true;
                    nvidia = {
                      modesetting.enable = true;
                      open = false;
                      nvidiaSettings = false;
                      package = config.boot.kernelPackages.nvidiaPackages.stable;
                    };
                  };
                  services.xserver.videoDrivers = [ "nvidia" ];
                }
              )
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
          {
            networking = {
              hostName = "devstral";
              domain = "local";
              useDHCP = true;
              firewall = {
                # Ollama has no authentication or TLS.  Restrict both
                # Ollama and mDNS to the trusted private LAN.
                extraCommands = ''
                  iptables -A nixos-fw -s 192.168.0.0/16 -p tcp --dport 11434 -j nixos-fw-accept
                  iptables -A nixos-fw -s 192.168.0.0/16 -p udp --dport 5353 -j nixos-fw-accept
                '';
                extraStopCommands = ''
                  iptables -D nixos-fw -s 192.168.0.0/16 -p tcp --dport 11434 -j nixos-fw-accept || true
                  iptables -D nixos-fw -s 192.168.0.0/16 -p udp --dport 5353 -j nixos-fw-accept || true
                '';
              };
            };
            services.avahi = {
              enable = true;
              nssmdns4 = true;
              publish.enable = true;
              extraServiceFiles = {
                ollama = ''
                  <?xml version="1.0" standalone="no"?>
                  <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
                  <service-group>
                    <name replace-wildcards="yes">Ollama on %h</name>
                    <service>
                      <type>_ollama._tcp</type>
                      <port>11434</port>
                    </service>
                  </service-group>
                '';
                http = ''
                  <?xml version="1.0" standalone="no"?>
                  <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
                  <service-group>
                    <name replace-wildcards="yes">HTTP on %h</name>
                    <service>
                      <type>_http._tcp</type>
                      <port>11434</port>
                    </service>
                  </service-group>
                '';
              };
            };
          }
          (
            { config, pkgs, ... }:
            {
              services.ollama = {
                enable = true;
                package = pkgs.ollama-cuda;
                host = "0.0.0.0";
                port = 11434;
                environmentVariables = {
                  OLLAMA_KEEP_ALIVE = "-1";
                  OLLAMA_NUM_PARALLEL = "1";
                };
                models = "${pkgs.runCommand "ollama-devstral-model" {
                  __noChroot = true;
                  nativeBuildInputs = [
                    pkgs.curl
                    pkgs.ollama-cuda
                  ];
                } (builtins.readFile ./scripts/embed-devstral.sh)}";
              };
              systemd.services.ollama.serviceConfig.ExecStartPost = [
                "${pkgs.curl}/bin/curl --fail --silent --show-error --retry 60 --retry-delay 1 --retry-connrefused -H 'Content-Type: application/json' -d '{\"model\":\"devstral\",\"prompt\":\"warm up\",\"stream\":false}' http://127.0.0.1:11434/api/generate --output /dev/null"
              ];
              hardware = {
                graphics.enable = true;
                nvidia = {
                  modesetting.enable = true;
                  open = false;
                  nvidiaSettings = false;
                  package = config.boot.kernelPackages.nvidiaPackages.stable;
                };
              };
              services.xserver.videoDrivers = [ "nvidia" ];
            }
          )
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
