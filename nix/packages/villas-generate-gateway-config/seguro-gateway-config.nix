# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{
  lib,
  config, # Input config
  ...
}:
with builtins // lib;
let
  # Optional environment variables
  env = lib.filterAttrs (n: v: v != "") {
    demoData = getEnv "DEMO_DATA"; # Generate random test data instead of communicating with real OPC-UA device
    digestsURI = getEnv "DIGESTS_URI"; # Path to VILLAS digest FIFO
    mqttHost = getEnv "MQTT_HOST";
    mqttPort = getEnv "MQTT_PORT";
    mqttUsername = getEnv "MQTT_USERNAME";
    mqttPassword = getEnv "MQTT_PASSWORD";
    debug = getEnv "DEBUG";
  };

  # Default values
  demoData = (env.demoData or "") != "";
  debug = (env.debug or "") != "";
  digestsURI = env.digestsURI or "/run/villas-digests.fifo";
  mqttHost = env.mqttHost or config.mqtt.host or "localhost";
  mqttPort = env.mqttPort or config.mqtt.port or 1883;

  mqttNode = md: mp: {
    name = "mqtt_${md.uid}_${mp.uid}";
    value = {
      type = "mqtt";
      format = "protobuf";
      host = mqttHost;
      port = mqttPort;
      out = {
        publish = "data/measurements/${config.uid}/${md.uid}/${mp.uid}";
      };
    };
  };

  opcuaNode = md: {
    name = "opcua_${md.uid}";
    value =
      let
        perChannel =
          ch:
          (
            if demoData then
              {
                name = toLower ch;
                signal = "random";
                amplitude = 1.0;
              }
            else
              {
                name = toLower ch;
                type = "complex";
                opcua_obj = ch;
                opcua_attr = "Momentary";
              }
          );

        signals = unique (concatMap (mp: (map perChannel mp.channels)) md.points);

        node =
          if demoData then
            {
              type = "signal.v2";
              rate = 10;
              realtime = true;
            }
          else
            {
              type = "exec";
              format = "villas.human";
              flush = true;
              exec = [ "opcua-readout" ];

              opcua_config = {
                inherit (md) uid;
                inherit (md) uri;
                port = md.port or 4840;
                sending_rate = md.sending_rate or 100.0;
              };
            };
      in
      node
      // {
        "in" = {
          inherit signals;

          hooks = [ { type = "stats"; } ];
        };
      };
  };

  opcuaNodes = listToAttrs (map opcuaNode config.devices);

  mqttNodes = listToAttrs (concatMap (md: (map (mp: mqttNode md mp) md.points)) config.devices);
in
{
  stats = 1.0;

  nodes = mqttNodes // opcuaNodes;

  paths = concatMap (
    md:
    (map (mp: {
      "in" = map (ch: "opcua_${md.uid}.${toLower ch}") mp.channels;
      "out" = "mqtt_${md.uid}_${mp.uid}";

      hooks = [
        {
          type = "frame";
          trigger = "timestamp";
          interval = 10;
          unit = "seconds";
        }
        {
          type = "digest";
          uri = "${digestsURI}";
          algorithm = "sha256";
        }
      ] ++ lib.optionals debug [ { type = "print"; } ];
    }) md.points)
  ) config.devices;
}
