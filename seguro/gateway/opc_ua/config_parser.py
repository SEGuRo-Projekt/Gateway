# SPDX-FileCopyrightText: 2023 Felix Wege, EONERC-ACS, RWTH Aachen University
# SPDX-License-Identifier: Apache-2.0
from schema import Or, Optional, Schema, SchemaError
import json
from enum import Enum

from seguro.gateway.opc_ua.logger import log_msg


class Type(Enum):
    VOLTAGE = 0
    CURRENT = 1
    FREQUENCY = 2
    POWER = 3


opcua_objects = {
    "U1": Type.VOLTAGE,
    "U2": Type.VOLTAGE,
    "U3": Type.VOLTAGE,
    "Freq": Type.FREQUENCY,
    "IG1_I1": Type.CURRENT,
    "IG1_I2": Type.CURRENT,
    "IG1_I3": Type.CURRENT,
    "IG1_I4": Type.CURRENT,
    "IG2_I1": Type.CURRENT,
    "IG2_I2": Type.CURRENT,
    "IG2_I3": Type.CURRENT,
    "IG2_I4": Type.CURRENT,
    "IG3_I1": Type.CURRENT,
    "IG3_I2": Type.CURRENT,
    "IG3_I3": Type.CURRENT,
    "IG3_I4": Type.CURRENT,
    "IG1_I1_Power": Type.POWER,
    "IG1_I2_Power": Type.POWER,
    "IG1_I3_Power": Type.POWER,
    "IG1_I4_Power": Type.POWER,
    "IG2_I1_Power": Type.POWER,
    "IG2_I2_Power": Type.POWER,
    "IG2_I3_Power": Type.POWER,
    "IG2_I4_Power": Type.POWER,
    "IG3_I1_Power": Type.POWER,
    "IG3_I2_Power": Type.POWER,
    "IG3_I3_Power": Type.POWER,
    "IG3_I4_Power": Type.POWER,
    "Module1_IG1_I1": Type.CURRENT,
    "Module1_IG1_I2": Type.CURRENT,
    "Module1_IG1_I3": Type.CURRENT,
    "Module1_IG1_I4": Type.CURRENT,
    "Module1_IG2_I1": Type.CURRENT,
    "Module1_IG2_I2": Type.CURRENT,
    "Module1_IG2_I3": Type.CURRENT,
    "Module1_IG2_I4": Type.CURRENT,
    "Module1_IG1_I1_Power": Type.POWER,
    "Module1_IG1_I2_Power": Type.POWER,
    "Module1_IG1_I3_Power": Type.POWER,
    "Module1_IG1_I4_Power": Type.POWER,
    "Module1_IG2_I1_Power": Type.POWER,
    "Module1_IG2_I2_Power": Type.POWER,
    "Module1_IG2_I3_Power": Type.POWER,
    "Module1_IG2_I4_Power": Type.POWER,
    "Module2_IG1_I1": Type.CURRENT,
    "Module2_IG1_I2": Type.CURRENT,
    "Module2_IG1_I3": Type.CURRENT,
    "Module2_IG1_I4": Type.CURRENT,
    "Module2_IG2_I1": Type.CURRENT,
    "Module2_IG2_I2": Type.CURRENT,
    "Module2_IG2_I3": Type.CURRENT,
    "Module2_IG2_I4": Type.CURRENT,
    "Module2_IG1_I1_Power": Type.POWER,
    "Module2_IG1_I2_Power": Type.POWER,
    "Module2_IG1_I3_Power": Type.POWER,
    "Module2_IG1_I4_Power": Type.POWER,
    "Module2_IG2_I1_Power": Type.POWER,
    "Module2_IG2_I2_Power": Type.POWER,
    "Module2_IG2_I3_Power": Type.POWER,
    "Module2_IG2_I4_Power": Type.POWER,
    "Module3_IG1_I1": Type.CURRENT,
    "Module3_IG1_I2": Type.CURRENT,
    "Module3_IG1_I3": Type.CURRENT,
    "Module3_IG1_I4": Type.CURRENT,
    "Module3_IG2_I1": Type.CURRENT,
    "Module3_IG2_I2": Type.CURRENT,
    "Module3_IG2_I3": Type.CURRENT,
    "Module3_IG2_I4": Type.CURRENT,
    "Module3_IG1_I1_Power": Type.POWER,
    "Module3_IG1_I2_Power": Type.POWER,
    "Module3_IG1_I3_Power": Type.POWER,
    "Module3_IG1_I4_Power": Type.POWER,
    "Module3_IG2_I1_Power": Type.POWER,
    "Module3_IG2_I2_Power": Type.POWER,
    "Module3_IG2_I3_Power": Type.POWER,
    "Module3_IG2_I4_Power": Type.POWER,
    "Module4_IG1_I1": Type.CURRENT,
    "Module4_IG1_I2": Type.CURRENT,
    "Module4_IG1_I3": Type.CURRENT,
    "Module4_IG1_I4": Type.CURRENT,
    "Module4_IG2_I1": Type.CURRENT,
    "Module4_IG2_I2": Type.CURRENT,
    "Module4_IG2_I3": Type.CURRENT,
    "Module4_IG2_I4": Type.CURRENT,
    "Module4_IG1_I1_Power": Type.POWER,
    "Module4_IG1_I2_Power": Type.POWER,
    "Module4_IG1_I3_Power": Type.POWER,
    "Module4_IG1_I4_Power": Type.POWER,
    "Module4_IG2_I1_Power": Type.POWER,
    "Module4_IG2_I2_Power": Type.POWER,
    "Module4_IG2_I3_Power": Type.POWER,
    "Module4_IG2_I4_Power": Type.POWER,
    "Module5_IG1_I1": Type.CURRENT,
    "Module5_IG1_I2": Type.CURRENT,
    "Module5_IG1_I3": Type.CURRENT,
    "Module5_IG1_I4": Type.CURRENT,
    "Module5_IG2_I1": Type.CURRENT,
    "Module5_IG2_I2": Type.CURRENT,
    "Module5_IG2_I3": Type.CURRENT,
    "Module5_IG2_I4": Type.CURRENT,
    "Module5_IG1_I1_Power": Type.POWER,
    "Module5_IG1_I2_Power": Type.POWER,
    "Module5_IG1_I3_Power": Type.POWER,
    "Module5_IG1_I4_Power": Type.POWER,
    "Module5_IG2_I1_Power": Type.POWER,
    "Module5_IG2_I2_Power": Type.POWER,
    "Module5_IG2_I3_Power": Type.POWER,
    "Module5_IG2_I4_Power": Type.POWER,
    "Module6_IG1_I1": Type.CURRENT,
    "Module6_IG1_I2": Type.CURRENT,
    "Module6_IG1_I3": Type.CURRENT,
    "Module6_IG1_I4": Type.CURRENT,
    "Module6_IG2_I1": Type.CURRENT,
    "Module6_IG2_I2": Type.CURRENT,
    "Module6_IG2_I3": Type.CURRENT,
    "Module6_IG2_I4": Type.CURRENT,
    "Module6_IG1_I1_Power": Type.POWER,
    "Module6_IG1_I2_Power": Type.POWER,
    "Module6_IG1_I3_Power": Type.POWER,
    "Module6_IG1_I4_Power": Type.POWER,
    "Module6_IG2_I1_Power": Type.POWER,
    "Module6_IG2_I2_Power": Type.POWER,
    "Module6_IG2_I3_Power": Type.POWER,
    "Module6_IG2_I4_Power": Type.POWER,
}


config_schema = Schema(
    {
        "uid": str,
        Optional("name"): str,
        Optional("description"): str,
        "uri": str,
        "port": Or(int, str),
        Optional("sending_rate"): float,
        Optional("mode"): Or("SUBSCRIBE", "GATHER"),
    }
)


def read_config(path: str):
    """Read config from file.

    Arguments:
        path {str} -- Path to the config file"""
    with open(path, encoding="utf-8") as file:
        config = json.load(file)
        log_msg(config)
    return config


def validate_config(config: dict, schema: Schema = config_schema):
    """Validate a config against the schema.

    Arguments:
        config {dict} -- Configuration to validate"""
    try:
        schema.validate(config)
    except SchemaError as se:
        log_msg("Config file is invalid!")
        raise se
    return config


def parse_opcua_objects(config: dict):
    """Parse opc ids from config and return as dict.

    Arguments:
        config {dict} -- Configuration to parse

    Returns:
        dict -- Parsed opc ids as {id:topic}"""
    ids = {}
    for signal in config["in"]["signals"]:
        if signal["opcua_obj"] not in ids:
            ids[signal["opcua_obj"]] = list()

        ids[signal["opcua_obj"]].append(signal["opcua_attr"])
    return ids
