{inputs, ...}: {
  imports = [inputs.agent-skills.homeManagerModules.default];

  programs.agent-skills = {
    enable = true;

    sources = {
      local.path = ./skills;
      mattpocock = {
        input = "mattpocock-skills";
        subdir = "skills/productivity";
      };
      emil = {
        input = "emilkowalski-skills";
        subdir = "skills";
      };
      caldoai = {
        input = "caldoai-skills";
        subdir = "skills";
      };
      ponytail = {
        input = "ponytail";
        subdir = "skills";
      };
      cloudflare-security-audit = {
        input = "cloudflare-security-audit";
        subdir = "skills";
      };
      taste-skill = {
        input = "taste-skill";
        subdir = "skills";
      };
      unslop = {
        input = "unslop-skill";
        subdir = "skills";
      };
    };

    skills = {
      enableAll = ["local" "caldoai" "emil" "ponytail" "cloudflare-security-audit" "taste-skill" "unslop"];
      enable = ["grilling" "grill-me"];
    };

    targets.claude.enable = true;

    # claude code keeps its claude.ai-synced skills in skills/synced, the sync's --delete would wipe them
    excludePatterns = ["/synced"];
  };
}
