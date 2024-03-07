# SPDX-FileCopyrightText: 2023 Felix Wege, EONERC-ACS, RWTH Aachen University
# SPDX-License-Identifier: Apache-2.0
from schema import Or, Optional, Schema, SchemaError
import json
from enum import Enum

from seguro.gateway.logger import log_msg


class Type(Enum):
    VOLTAGE = 0
    CURRENT = 1
    FREQUENCY = 2


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
}


config_schema = Schema(
    {
        "devices": [
            {
                "uid": str,
                Optional("name"): str,
                Optional("description"): str,
                "uri": str,
                "port": Or(int, str),
                Optional("sending_rate"): float,
                "measurements": {
                    lambda n: n
                    in opcua_objects: {
                        Optional("min"): bool,
                        Optional("max"): bool,
                        Optional("momentary"): bool,
                    }
                },
            }
        ]
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


def parse_opcua_ids(config: dict):
    """Parse opc ids from config and return as dict.

    Arguments:
        config {dict} -- Configuration to parse

    Returns:
        dict -- Parsed opc ids as {id:topic}"""
    ids = {}
    for signal in config["in"]["signals"]:
        if signal["opcua_id"] not in ids:
            ids[signal["opcua_id"]] = list()

        ids[signal["opcua_id"]].append(signal["attr"])
    return ids
