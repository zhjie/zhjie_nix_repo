{
  arrow-cpp,
  stdenv,
}:
if stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isx86_64 then
  (arrow-cpp.override {
    enableS3 = false;
    enableGcs = false;
    enableAzure = false;
  }).overrideAttrs (old: {
    meta = old.meta // {
      broken = false;
    };
  })
else
  arrow-cpp
