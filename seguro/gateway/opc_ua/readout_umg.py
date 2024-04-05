# SPDX-FileCopyrightText: 2023 Felix Wege, EONERC-ACS, RWTH Aachen University
# SPDX-License-Identifier: Apache-2.0
import asyncio
import os

from seguro.gateway.opc_ua.config_parser import (
    read_config,
    parse_opcua_objects,
    validate_config,
)
from seguro.gateway.opc_ua.logger import log_msg
from seguro.gateway.opc_ua.subscription_handler import Mode, read_measurements


def main():
    VILLAS_NODE_CONFIG = os.environ["VILLAS_NODE_CONFIG"]
    VILLAS_NODE_NAME = os.environ["VILLAS_NODE_NAME"]
    log_msg(VILLAS_NODE_CONFIG)
    log_msg(VILLAS_NODE_NAME)
    log_msg(f"Parsing config from {VILLAS_NODE_CONFIG}#{VILLAS_NODE_NAME}")

    vn_conf = read_config(VILLAS_NODE_CONFIG)["nodes"][VILLAS_NODE_NAME]
    opcua_objects = parse_opcua_objects(vn_conf)
    device_conf = validate_config(vn_conf["opcua"])
    mode = (
        Mode[device_conf["mode"]]
        if "mode" in device_conf.keys()
        else Mode["SUBSCRIBE"]
    )

    log_msg(f"Reading measurements in mode {mode}.")
    log_msg(f"Device configuration: {device_conf}")
    log_msg(f"OPC UA IDs: {opcua_objects}")

    asyncio.run(
        read_measurements(
            device_conf,
            opcua_objects,
            mode,
        )
    )


if __name__ == "__main__":
    main()
