{
  config,
  pkgs,
  ...
}:

let
  kernel = config.boot.kernelPackages.kernel;
  gpuUnlock = pkgs.callPackage ../pkgs/gpu-unlock-ada { inherit kernel; };
  firmware = gpuUnlock.firmware;
  firmwareVersion = gpuUnlock.firmwareVersion;
  kernelModule = gpuUnlock;
in
{
  boot = {
    extraModulePackages = [ kernelModule ];
    kernelParams = [ "gpu_unlock.targets=0000:01:00.0" ];

    initrd = {
      availableKernelModules = [ "gpu_unlock" ];
      extraFirmwarePaths = map (name: "gpu-unlock/${firmwareVersion}/${name}") [
        "booter_load_ga102.bin"
        "gsp_ga10x.bin"
        "gsp_boot_ga102.bin"
        "gsp_boot_desc_ga102.bin"
        "v67-ga102-${firmwareVersion}.bin"
        "booter_load_ad102.bin"
        "gsp_boot_ad102.bin"
        "gsp_boot_desc_ad102.bin"
        "v67-ad102-${firmwareVersion}-four-plm.bin"
      ];

      systemd = {
        storePaths = [ "${pkgs.kmod}/bin/modprobe" ];
        services.gpu-unlock = {
          description = "Unlock RTX 4090 tensor throughput before NVIDIA binds";
          wantedBy = [ "sysinit.target" ];
          # Module loading and udev coldplug otherwise run concurrently.
          before = [
            "systemd-udevd.service"
            "systemd-udev-trigger.service"
            "systemd-modules-load.service"
          ];
          unitConfig = {
            DefaultDependencies = false;
            ConditionKernelCommandLine = "gpu_unlock.targets";
          };
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.kmod}/bin/modprobe gpu_unlock";
            RemainAfterExit = true;
          };
        };
      };
    };
  };

  hardware.firmware = [ firmware ];
}
