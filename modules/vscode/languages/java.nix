{pkgs, ...}: {
  programs.vscodium.profiles.default = {
    extensions = with pkgs.open-vsx; [
      redhat.java
    ];
    userSettings = {
      "java.jdt.ls.java.home" = pkgs.javaPackages.compiler.temurin-bin.jdk-25.home;
    };
  };
}
