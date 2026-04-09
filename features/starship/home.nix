{ ... }:

{
  programs.starship = {
    enable = true;
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
