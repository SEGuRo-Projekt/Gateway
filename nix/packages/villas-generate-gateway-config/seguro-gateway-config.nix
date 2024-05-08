# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{
  lib,
  config, # Input config
  ...
}:
with builtins // lib;
let
  hasEnv = variable: getEnv variable != "";
  getEnvWithDefault = variable: default: if hasEnv variable then getEnv variable else default;

  # Default values
  demoData = hasEnv "DEMO_DATA";
  debug = hasEnv "DEBUG";

  mqttNode = md: mp: {
    name = "mqtt_${md.uid}_${mp.uid}";
    value = {
      type = "mqtt";
      format = "protobuf";
      host = getEnvWithDefault "MQTT_HOST" config.mqtt.host or "localhost";
      port = getEnvWithDefault "MQTT_PORT" config.mqtt.port or 1883;
      ssl = {
        cafile = getEnvWithDefault "TLS_CACERT" config.tls.cacert or "/boot/ca.crt";
        certfile = getEnvWithDefault "TLS_CERT" config.tls.cert or "/boot/mp.crt";
        keyfile = getEnvWithDefault "TLS_KEY" config.tls.key or "/boot/mp.key";
      };
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

  log = {
    level = if debug then "debug" else "info";
  };

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
          uri = getEnvWithDefault "DIGESTS_URI" "/run/villas-digests.fifo";
          algorithm = "sha256";
        }
      ] ++ lib.optionals debug [ { type = "print"; } ];
    }) md.points)
  ) config.devices;
}
