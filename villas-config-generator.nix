# SPDX-FileCopyrightText: 2024 OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{...} @ config: let
  firstDev = builtins.elemAt config.devices 0;
in {
  nodes = {
    ${firstDev.uid} = {
      topic = "";
      type = "mqtt";
    };

    opcua_ms1 = {
      "in" = {
        signals = [
          {
            name = "mp1_f";
            opcua_id = "U1";
            opcua_type = "min/max/momentary";
          }
          {
            name = "mp1_ua";
            opcua = {
              id = "";
              momementary = true;
            };
          }
          {
            name = "mp1_ub";
            opcua = {
              id = "";
              momementary = true;
            };
          }
          {
            name = "mp1_uc";
            opcua = {
              id = "";
              momementary = true;
            };
          }
          {
            name = "mp1_ia";
            opcua = {
              id = "";
              momementary = true;
            };
          }
          {
            name = "mp1_ib";
            opcua = {
              id = "";
              momementary = true;
            };
          }
          {
            name = "mp1_ic";
            opcua = {
              id = "";
              momementary = true;
            };
          }
          {
            name = "mp2_f";
            opcua = {
              id = "";
              momementary = true;
            };
          }
          {
            name = "mp2_ua";
            opcua = {
              id = "";
              momementary = true;
            };
          }
          {
            name = "mp2_ub";
            opcua = {
              id = "";
              momementary = true;
            };
          }
          {
            name = "mp2_uc";
            opcua = {
              id = "";
              momementary = true;
            };
          }
          {
            name = "mp2_ia";
            opcua = {
              id = "";
              momementary = true;
            };
          }
          {
            name = "mp2_ib";
            opcua = {
              id = "";
              momementary = true;
            };
          }
          {
            name = "mp2_ic";
            opcua = {
              id = "";
              momementary = true;
            };
          }
        ];
      };
      opcua = {uri = "";};
      script = "python3 scr";
      type = "exec";
    };
  };

  paths = [
    {
      hooks = [{type = "block";} {type = "sign";}];
      "in" = ["opcua_ms1.mp1_f" "opcua_ms1.mp1_ua" "opcua_ms1.mp1_ub" "opcua_ms1.mp1_uc" "opcua_ms1.mp1_ia" "opcua_ms1.mp1_ib" "opcua_ms1.mp1_ic"];
      out = "mqtt_ms1_mp1";
    }
    {
      "in" = ["opcua_ms1.mp2_f" "opcua_ms1.mp2_ua" "opcua_ms1.mp2_ub" "opcua_ms1.mp2_uc" "opcua_ms1.mp2_ia" "opcua_ms1.mp2_ib" "opcua_ms1.mp2_ic"];
      out = "mqtt_ms1_mp2";
    }
  ];
}
