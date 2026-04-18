{ config, ... }:
let
  # place bookmarks.private.nix in ~/.config/nix/bookmarks.private.nix
  privatePath = /. + "${config.xdg.configHome}/nix/bookmarks.private.nix";
  privateBookmarks = if builtins.pathExists privatePath then import privatePath else [ ];
in
[
  {
    name = "toolbar";
    toolbar = true;
    bookmarks = [
      {
        name = "";
        url = "https://www.youtube.com/";
      }
      {
        name = "";
        url = "https://bsky.app/";
      }
      {
        name = "";
        url = "https://x.com/";
      }
      {
        name = "";
        url = "https://soundcloud.com/";
      }
      {
        name = "";
        url = "https://mail.proton.me/";
      }
      {
        name = "";
        url = "https://www.furaffinity.net/";
      }
      {
        name = "";
        url = "https://app.ynab.com/";
      }
      {
        name = "";
        url = "https://www.notion.com/";
      }
      {
        name = "";
        url = "https://auth.mesa.tetra.cool/if/user/#/library";
      }
      {
        name = "";
        url = "https://unifi.mesa.tetra.cool/";
      }
      {
        name = "";
        url = "http://home.mesa.tetra.cool/";
      }
      {
        name = "games";
        bookmarks = [
          {
            name = "Vimm's Lair: The Vault";
            url = "https://vimm.net/?p=vault";
          }
          {
            name = "steamdb free packages";
            url = "https://steamdb.info/freepackages/";
          }
          {
            name = "VRC Timeline";
            url = "https://vrc.tl/";
          }
          {
            name = "PP Booster";
            url = "https://bs-pp-booster.abachelet.fr/";
          }
          {
            name = "Beat Savior";
            url = "https://www.beatsavior.io/";
          }
          {
            name = "ScoreSaber";
            url = "https://scoresaber.com/u/76561198184647378";
          }
        ];
      }
      {
        name = "puter";
        bookmarks = [
          {
            name = "new pc";
            url = "https://pcpartpicker.com/list/TTGYn7";
          }
          {
            name = "old pc";
            url = "https://pcpartpicker.com/list/tkFqTC";
          }
          {
            name = "NVIDIA Video Encode/Decode GPU Support Matrix";
            url = "https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new";
          }
        ];
      }
      {
        name = "homelab";
        bookmarks = [
          {
            name = "Proxmox Helper Scripts";
            url = "https://tteck.github.io/Proxmox/";
          }
          {
            name = "DIY Thread Border Router for $5";
            url = "https://community.home-assistant.io/t/make-your-own-thread-border-router-for-just-5/962780";
          }
          {
            name = "Usenet Providers and Backbones";
            url = "https://upload.wikimedia.org/wikipedia/commons/7/7d/Usenet_Providers_and_Backbones.svg";
          }
          {
            name = "The Twelve-Factor App";
            url = "https://www.12factor.net/";
          }
        ];
      }
      {
        name = "music";
        bookmarks = [
          {
            name = "Seattle Electronic Music Events";
            url = "https://19hz.info/eventlisting_Seattle.php";
          }
          {
            name = "Tempo and Pitch Calculators";
            url = "http://www.thewhippinpost.co.uk/tools/tempo-pitch-calculator.htm";
          }
          {
            name = "Ableton Audio Fact Sheet";
            url = "https://www.ableton.com/en/manual/audio-fact-sheet/";
          }
          {
            name = "grape milk - CAN YOU HEAR ME (Sample Pack)";
            url = "https://shop.halcyon.fm/cyhm";
          }
          {
            name = "trndy released";
            url = "https://drive.google.com/drive/u/0/folders/16RWJFFs-7L1gXa4_DyQMvFFeaaW-ZHmP";
          }
          {
            name = "fc05 - album of the summer";
            url = "https://drive.google.com/drive/folders/1GtZiB-8MCFRcUo3HfmHRiDdmACXYGjAT";
          }
        ];
      }
      {
        name = "shoppies";
        bookmarks = [
          {
            name = "Etymotic ER20XS";
            url = "https://www.etymotic.com/product/er20xs/";
          }
          {
            name = "LATEX BODYSUIT FOR YOUR PLEASURE : FORFUN";
            url = "https://www.forfun.store/fetish-wear/bodysuit/men-bodysuit/latex-playsuit-men-bs01-m-01";
          }
          {
            name = "The Warrant Tee - Cool Shirtz";
            url = "https://shirtz.cool/products/the-warrant-tee?variant=40502785769570";
          }
          {
            name = "The High Five Duo";
            url = "https://highfivevape.com/products/the-duo";
          }
          {
            name = "2 Layer Sled Harness";
            url = "https://www.warhorseworkshop.net/store/p299/2_Layer_Sled_Harness_with_Leg_Straps.html";
          }
          {
            name = "Kosse's things";
            url = "https://kosse.dog/";
          }
        ];
      }
      {
        name = "misc";
        bookmarks = [
          {
            name = "unlimited:waifu2x";
            url = "https://unlimited.waifu2x.net/";
          }
          {
            name = "eightyeightthirtyone";
            url = "https://eightyeightthirty.one/";
          }
        ];
      }
      {
        name = "szop callout (Szopument)";
        url = "https://docs.google.com/document/d/1KnLYCH939EsKjbhgAnq9IAphJ_UNQwZTEFzEa5lSWGs/edit?tab=t.0";
      }
      {
        name = "Skrillex - Feb 1, 2015";
        url = "https://x.com/Skrillex/status/562121140525473793";
      }
    ]
    ++ privateBookmarks;
  }
]
