{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # ─── Boot ────────────────────────────────────────────────
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  # ─── Proxmox ─────────────────────────────────────────────
  services.qemuGuest.enable = true;

  # ─── Système ─────────────────────────────────────────────
  networking.hostName = "NixWeb";
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 ];

  time.timeZone = "Europe/Paris";

  environment.systemPackages = with pkgs; [ git vim nodejs_24 ];

  # ─── Utilisateurs ────────────────────────────────────────
  users.users.deafiaa = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    shell = pkgs.zsh;
    # openssh.authorizedKeys.keys = [
    #   TODO XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
    # ];
  };
  programs.zsh.enable = true;

  # ─── SSH ─────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };

  # ─── NGINX : frontend compilé + /api vers le backend ─────
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    virtualHosts."app.lan" = {
      root = "/srv/project-04/frontend/dist";
      locations."/".tryFiles = "$uri $uri/ /index.html";
      locations."/api/".proxyPass = "http://127.0.0.1:3000";
    };
  };

  # ─── Docker + MongoDB (accessible uniquement depuis la VM) ─
  virtualisation.docker.enable = true;
  virtualisation.oci-containers = {
    backend = "docker";
    containers.mongo = {
      image = "mongo:7.0";
      ports = [ "127.0.0.1:27017:27017" ];
      volumes = [ "/var/lib/mongo:/data/db" ];
    };
  };

  # ─── Backend Express en service systemd ──────────────────
  systemd.services.project04-backend = {
    description = "Project-04 API";
    after = [ "network.target" "docker-mongo.service" ];
    requires = [ "docker-mongo.service" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      PORT = "3000";
      MONGO_URI = "mongodb://127.0.0.1:27017/project-04";
    };
    serviceConfig = {
      User = "deafiaa";
      WorkingDirectory = "/srv/project-04/backend";
      ExecStart = "${pkgs.nodejs_24}/bin/node src/server.js";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # Ne pas modifier (version d'installation initiale).
  system.stateVersion = "26.05";
}
