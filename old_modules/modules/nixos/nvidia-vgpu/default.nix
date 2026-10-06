inputs: {
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.hardware.nvidia.vgpu;

  geforce-driver-version = "535.129.03"; # "535.129.03";
  grid-driver-version = "535.129.03";
  wdys-driver-version = "537.70";
  grid-version = "16.2";
in let
  mdevctl = pkgs.callPackage ./mdevctl {};
  combinedZipName = "NVIDIA-GRID-Linux-KVM-${grid-driver-version}-${wdys-driver-version}.zip";
  requireFile = {name, ...} @ args:
    pkgs.requireFile (rec {
        inherit name;
        url = "https://www.nvidia.com/object/vGPU-software-driver.html";
        message = ''
          Unfortunately, we cannot download file ${name} automatically.
          This file can be extracted from ${combinedZipName}.
          Please go to ${url} to download it yourself or ask the vgpu discord community for support (https://discord.com/invite/5rQsSV3Byq)
          You can see the related nvidia driver versions here: https://docs.nvidia.com/grid/index.html. Add it to the Nix store
          using either
            nix-store --add-fixed sha256 ${name}
          or
            nix-prefetch-url --type sha256 file:///path/to/${name}

          If you already added the file, maybe the sha256 is wrong, use `nix hash file ${name}` and the option vgpu_driver_src.sha256 to override the hardcoded hash.
        '';
      }
      // args);

  vpgu-src = pkgs.stdenv.mkDerivation {
    name = "vpgu-src";
    nativeBuildInputs = [pkgs.p7zip pkgs.unzip pkgs.coreutils pkgs.bash pkgs.zstd];
    system = "x86_64-linux";
    src = requireFile {
      name = "NVIDIA-GRID-Linux-KVM-${grid-driver-version}-${wdys-driver-version}.zip";
      sha256 = cfg.grid_driver_zip.sha256; # nix hash file foo.txt
    };

    dontUnpack = true;
    buildPhase = ''
      mkdir -p $out
      cd $TMPDIR
      ${pkgs.unzip}/bin/unzip -j $src Host_Drivers/NVIDIA-Linux-x86_64-${grid-driver-version}-vgpu-kvm.run
      ${pkgs.unzip}/bin/unzip -j $src Guest_Drivers/NVIDIA-Linux-x86_64-${grid-driver-version}-grid.run
      cp -a NVIDIA-Linux-x86_64-${grid-driver-version}-vgpu-kvm.run $out/
      # cd $out
      # export kvmrun=$out/NVIDIA-Linux-x86_64-${grid-driver-version}-vgpu-kvm.run
      # skip=$(sed 's/^skip=//; t; d' $kvmrun)
      # tail -n +$skip $kvmrun | xz -d | tar xvf -
      # cd ..
      cp -a NVIDIA-Linux-x86_64-${grid-driver-version}-grid.run $out/
      cd $out
      chmod +x NVIDIA-Linux-x86_64-${grid-driver-version}-vgpu-kvm.run
      ./NVIDIA-Linux-x86_64-${grid-driver-version}-vgpu-kvm.run -x
      chmod +x NVIDIA-Linux-x86_64-${grid-driver-version}-grid.run
      ./NVIDIA-Linux-x86_64-${grid-driver-version}-grid.run -x
    '';
  };
in {
  options = {
    hardware.nvidia.vgpu = {
      enable = lib.mkEnableOption "vGPU support";

      grid_driver_zip.sha256 = lib.mkOption {
        default = "";
        type = lib.types.str;
        description = ''
          sha256 of the vgpu_driver file in case you're having trouble adding it with for Example `nix-store --add-fixed sha256 NVIDIA-GRID-Linux-KVM-535.129.03-537.70.zip`
          You can find the hash of the file with `nix hash file foo.txt`
        '';
      };

      # submodule
      fastapi-dls = lib.mkOption {
        description = "Set up fastapi-dls host server";
        type = with lib.types;
          submodule {
            options = {
              enable = lib.mkOption {
                default = false;
                type = lib.types.bool;
                description = "Set up fastapi-dls host server";
              };
              docker-directory = lib.mkOption {
                description = "Path to your folder with docker containers";
                default = "/opt/docker";
                example = "/dockers";
                type = lib.types.str;
              };
              local_ipv4 = lib.mkOption {
                description = "Your ipv4 or local hostname, needed for the fastapi-dls server. Leave blank to autodetect using hostname";
                default = "";
                example = "192.168.1.81";
                type = lib.types.str;
              };
              timezone = lib.mkOption {
                description = "Your timezone according to this list: https://docs.diladele.com/docker/timezones.html, needs to be the same as in the VM. Leave blank to autodetect";
                default = "";
                example = "Europe/Lisbon";
                type = lib.types.str;
              };
            };
          };
        default = {};
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable.overrideAttrs ( # CHANGE stable to legacy_470 to pin the version of the driver if it stops working
        {
          patches ? [],
          postUnpack ? "",
          postPatch ? "",
          preFixup ? "",
          prePatch ? "",
          ...
        }: {
          # Overriding https://github.com/NixOS/nixpkgs/tree/nixos-unstable/pkgs/os-specific/linux/nvidia-x11
          # that gets called from the option hardware.nvidia.package from here: https://github.com/NixOS/nixpkgs/blob/nixos-22.11/nixos/modules/hardware/video/nvidia.nix
          name = "nvidia-x11-${geforce-driver-version}-vgpu-kvm-${config.boot.kernelPackages.kernel.version}";
          version = "${geforce-driver-version}";

          # the new driver (compiled in a derivation above)

          src = requireFile {
            name = "NVIDIA-Linux-x86_64-${geforce-driver-version}-grid.run";
            sha256 = "sha256-RWemnuEuZRPszUvy+Mj1/rXa5wn8tsncXMeeJHKnCxw=";
          };
          patches =
            [(builtins.elemAt patches 0)]
            ++ [
              ./nvidia-vgpu-merge.patch
            ];

          prePatch = ''
            # More merging, besides patch above
            cp -r ${vpgu-src}/NVIDIA-Linux-x86_64-${geforce-driver-version}-vgpu-kvm/init-scripts .
            cp ${vpgu-src}/NVIDIA-Linux-x86_64-${geforce-driver-version}-vgpu-kvm/kernel/common/inc/nv-vgpu-vfio-interface.h kernel/common/inc/nv-vgpu-vfio-interface.h
            cp ${vpgu-src}/NVIDIA-Linux-x86_64-${geforce-driver-version}-vgpu-kvm/kernel/nvidia/nv-vgpu-vfio-interface.c kernel/nvidia/nv-vgpu-vfio-interface.c
            echo "NVIDIA_SOURCES += nvidia/nv-vgpu-vfio-interface.c" >> kernel/nvidia/nvidia-sources.Kbuild
            cp -r ${vpgu-src}/NVIDIA-Linux-x86_64-${geforce-driver-version}-vgpu-kvm/kernel/nvidia-vgpu-vfio kernel/nvidia-vgpu-vfio

            for i in libnvidia-vgpu.so.${geforce-driver-version} libnvidia-vgxcfg.so.${geforce-driver-version} nvidia-vgpu-mgr nvidia-vgpud vgpuConfig.xml sriov-manage; do
              cp ${vpgu-src}/NVIDIA-Linux-x86_64-${geforce-driver-version}-vgpu-kvm/$i $i
            done

            chmod -R u+rw .
          '';

          postPatch = ''
            # Move path for vgpuConfig.xml into /etc
            sed -i 's|/usr/share/nvidia/vgpu|/etc/nvidia-vgpu-xxxxx|' nvidia-vgpud

            substituteInPlace sriov-manage \
              --replace lspci ${pkgs.pciutils}/bin/lspci \
              --replace setpci ${pkgs.pciutils}/bin/setpci
          '';

          # HACK: Using preFixup instead of postInstall since nvidia-x11 builder.sh doesn't support hooks
          preFixup =
            preFixup
            + ''
              for i in libnvidia-vgpu.so.${geforce-driver-version} libnvidia-vgxcfg.so.${geforce-driver-version}; do
                install -Dm755 "$i" "$out/lib/$i"
              done
              patchelf --set-rpath ${pkgs.stdenv.cc.cc.lib}/lib $out/lib/libnvidia-vgpu.so.${geforce-driver-version}
              install -Dm644 vgpuConfig.xml $out/vgpuConfig.xml

              for i in nvidia-vgpud nvidia-vgpu-mgr; do
                install -Dm755 "$i" "$bin/bin/$i"
                # stdenv.cc.cc.lib is for libstdc++.so needed by nvidia-vgpud
                patchelf --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
                  --set-rpath $out/lib "$bin/bin/$i"
              done
              install -Dm755 sriov-manage $bin/bin/sriov-manage
            '';
        }
      );

      systemd.services.nvidia-vgpud = {
        description = "NVIDIA vGPU Daemon";
        wants = ["syslog.target"];
        wantedBy = ["multi-user.target"];

        serviceConfig = {
          Type = "forking";
          ExecStart = "${lib.getBin config.hardware.nvidia.package}/bin/nvidia-vgpud";
          ExecStopPost = "${pkgs.coreutils}/bin/rm -rf /var/run/nvidia-vgpud";
          Environment = ["__RM_NO_VERSION_CHECK=1"]; # Avoids issue with API version incompatibility when merging host/client drivers
        };
      };

      systemd.services.nvidia-vgpu-mgr = {
        description = "NVIDIA vGPU Manager Daemon";
        wants = ["syslog.target"];
        wantedBy = ["multi-user.target"];

        serviceConfig = {
          Type = "forking";
          KillMode = "process";
          ExecStart = "${lib.getBin config.hardware.nvidia.package}/bin/nvidia-vgpu-mgr";
          ExecStopPost = "${pkgs.coreutils}/bin/rm -rf /var/run/nvidia-vgpu-mgr";
          Environment = ["__RM_NO_VERSION_CHECK=1" "LD_LIBRARY_PATH=LD_LIBRARY_PATH:${pkgs.glib.out}/lib" "LD_PRELOAD=LD_PRELOAD:${pkgs.glib.out}/lib"];
        };
      };

      boot.extraModprobeConfig = ''
        options nvidia vup_sunlock=1 vup_swrlwar=1 vup_qmode=1
      ''; # (for driver 535) bypasses `error: vmiop_log: NVOS status 0x1` in nvidia-vgpu-mgr.service when starting VM

      environment.etc."nvidia-vgpu-xxxxx/vgpuConfig.xml".source = config.hardware.nvidia.package + /vgpuConfig.xml;

      boot.kernelModules = ["nvidia-vgpu-vfio"];

      environment.systemPackages = [mdevctl];
      services.udev.packages = [mdevctl];
    })

    (lib.mkIf cfg.fastapi-dls.enable {
      virtualisation.oci-containers.containers = {
        fastapi-dls = {
          image = "collinwebdesigns/fastapi-dls";
          imageFile = pkgs.dockerTools.pullImage {
            imageName = "collinwebdesigns/fastapi-dls";
            imageDigest = "sha256:6fa90ce552c4e9ecff9502604a4fd42b3e67f52215eb6d8de03a5c3d20cd03d1";
            sha256 = "1y642miaqaxxz3z8zkknk0xlvzxcbi7q7ylilnxhxfcfr7x7kfqa";
          };
          volumes = [
            "${cfg.fastapi-dls.docker-directory}/fastapi-dls/cert:/app/cert:rw"
            "dls-db:/app/database"
          ];
          # Set environment variables
          environment = {
            TZ =
              if cfg.fastapi-dls.timezone == ""
              then config.time.timeZone
              else "${cfg.fastapi-dls.timezone}";
            DLS_URL =
              if cfg.fastapi-dls.local_ipv4 == ""
              then config.networking.hostName
              else "${cfg.fastapi-dls.local_ipv4}";
            DLS_PORT = "443";
            LEASE_EXPIRE_DAYS = "90";
            DATABASE = "sqlite:////app/database/db.sqlite";
            DEBUG = "true";
          };
          extraOptions = [
          ];
          # Publish the container's port to the host
          ports = ["443:443"];
          # Do not automatically start the container, it will be managed
          autoStart = false;
        };
      };

      systemd.timers.fastapi-dls-mgr = {
        wantedBy = ["multi-user.target"];
        timerConfig = {
          OnActiveSec = "1s";
          OnUnitActiveSec = "1h";
          AccuracySec = "1s";
          Unit = "fastapi-dls-mgr.service";
        };
      };

      systemd.services.fastapi-dls-mgr = {
        path = [pkgs.openssl];
        script = ''
          WORKING_DIR=${cfg.fastapi-dls.docker-directory}/fastapi-dls/cert
          CERT_CHANGED=false
          recreate_private () {
            rm -f $WORKING_DIR/instance.private.pem
            openssl genrsa -out $WORKING_DIR/instance.private.pem 2048
          }
          recreate_public () {
            rm -f $WORKING_DIR/instance.public.pem
            openssl rsa -in $WORKING_DIR/instance.private.pem -outform PEM -pubout -out $WORKING_DIR/instance.public.pem
          }
          recreate_certs () {
            rm -f $WORKING_DIR/webserver.key
            rm -f $WORKING_DIR/webserver.crt
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $WORKING_DIR/webserver.key -out $WORKING_DIR/webserver.crt -subj "/C=XX/ST=StateName/L=CityName/O=CompanyName/OU=CompanySectionName/CN=CommonNameOrHostname"
          }
          check_recreate() {
            if [ ! -e $WORKING_DIR/instance.private.pem ]; then
              recreate_private
              recreate_public
              recreate_certs
              CERT_CHANGED=true
            fi
            if [ ! -e $WORKING_DIR/instance.public.pem ]; then
              recreate_public
              recreate_certs
              CERT_CHANGED=true
            fi
            if [ ! -e $WORKING_DIR/webserver.key ] || [ ! -e $WORKING_DIR/webserver.crt ]; then
              recreate_certs
              CERT_CHANGED=true
            fi
            if ( ! openssl x509 -checkend 864000 -noout -in $WORKING_DIR/webserver.crt); then
              recreate_certs
              CERT_CHANGED=true
            fi
          }
          if [ ! -d $WORKING_DIR ]; then
            mkdir -p $WORKING_DIR
          fi
          check_recreate
          if ( ! systemctl is-active --quiet docker-fastapi-dls.service ); then
            systemctl start podman-fastapi-dls.service
          elif $CERT_CHANGED; then
            systemctl stop podman-fastapi-dls.service
            systemctl start podman-fastapi-dls.service
          fi
        '';
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      };
    })
  ];
}
