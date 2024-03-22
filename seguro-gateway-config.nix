
# SPDX-FileCopyrightText: 2024 OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{
  lib,
  config,
  opcua_readout_umg ? "readout_umg",
  ...
}:
with builtins;
with lib; let
  mqttNode = md: mp: {
    name = "mqtt_${md.uid}_${mp.uid}";
    value = {
      type = "mqtt";
      format = "protobuf";
      host = config.mqtt.host or "localhost";
      port = config.mqtt.port or 1883;
      out = {
        publish = "measurements/${config.uid}/${md.uid}/${mp.uid}";
      };
    };
  };

  opcuaNode = md: {
    name = "opcua_${md.uid}";
    value = {
      type = "exec";
      format = "villas.human";
      flush = true;
      exec = [opcua_readout_umg];

      "in" = {
        signals = unique (concatMap (
            mp: (
              map (ch: {
                name = toLower ch;
                type = "complex";
                opcua_obj = ch;
                opcua_attr = "Momentary";
              })
              mp.channels
            )
          )
          md.points);
      };

      opcua_config = {
        inherit (md) uid;
        inherit (md) uri;
        port = md.port or 4840;
        sending_rate = md.sending_rate or 100;
      };
    };
  };

  opcuaNodes = listToAttrs (
    map opcuaNode config.devices
  );

  mqttNodes = listToAttrs (
    concatMap (
      md: (
        map (mp: mqttNode md mp)
        md.points
      )
    )
    config.devices
  );
in {
  nodes = mqttNodes // opcuaNodes;

  paths =
    concatMap (
      md: (
        map (mp: {
          "in" = map (ch: "opcua_${md.uid}.${toLower ch}") mp.channels;
          out = "mqtt_${md.uid}_${mp.uid}";
        })
        md.points
      )
    )
    config.devices;
}
