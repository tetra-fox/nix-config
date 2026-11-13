_: {
  programs.starship = {
    enable = true;
    # the default emoji symbols carry U+FE0F, which kitty draws 2 cells wide but zsh
    # counts as 1, so zle redraws the line one column off. nerd font glyphs are 1 in both
    # TODO: drop if zsh learns emoji presentation widths, https://zsh.org/mla/workers/2024/msg00495.html
    presets = ["nerd-font-symbols"];
    settings = {
      format = "$directory$character";
      right_format = "$all$status";
      status = {
        disabled = false;
        format = "[$symbol]($style)";
        symbol = "✘";
        style = "bold red";
        success_symbol = "✔";
        success_style = "bold green";
      };
    };
  };
}
