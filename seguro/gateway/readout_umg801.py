# SPDX-FileCopyrightText: 2023 Felix Wege, EONERC-ACS, RWTH Aachen University
# SPDX-License-Identifier: Apache-2.0
import asyncio
from asyncua import Client
import argparse

from enum import Enum

import yaml
from schema import Or, Optional, Schema, SchemaError

import time

opcua_objects = [
    "U1",
    "U2",
    "U3",
    "Freq",
    "IG1/I1",
    "IG1/I2",
    "IG1/I3",
    "IG1/I4",
    "IG2/I1",
    "IG2/I2",
    "IG2/I3",
    "IG2/I4",
    "IG3/I1",
    "IG3/I2",
    "IG3/I3",
    "IG3/I4",
]


config_schema = Schema(
    {
        "devices": [
            {
                "uid": str,
                Optional("name"): str,
                Optional("description"): str,
                "uri": str,
                "port": Or(int, str),
                Optional("sample_rate"): float,
                "measurements": {
                    lambda n: n
                    in opcua_objects: {
                        "type": Or("voltage", "current", "frequency"),
                        Optional("min"): bool,
                        Optional("max"): bool,
                        Optional("momentary"): bool,
                    }
                },
            }
        ]
    }
)


def read_config(path: str, schema: Schema):
    """Read config file and validate it against the schema.

    Arguments:
        path {str} -- Path to the config file"""
    with open(path, encoding="utf-8") as file:
        config = yaml.safe_load(file)
        try:
            schema.validate(config)
        except SchemaError as se:
            print("Config file is invalid!")
            raise se
    return config


def exist_and_true(dct: dict, key: str):
    """Check if key exists in dict and if it is true.

    Arguments:
        input {dict} -- Input dict
        key {str} -- Key to check

    Returns:
        bool -- True if key exists and is true, False otherwise
    """
    if key in dct.keys():
        return dct[key]
    else:
        return False


def nodeid_to_string(nodeid):
    """Convert a nodeid object to string.

    Arguments:
        nodeid {NodeId} -- Nodeid to convert
    """
    return f"ns={nodeid.NamespaceIndex};i={nodeid.Identifier}"


def construct_browse_paths(uid: str, measurements: dict):
    """
    Construct browse paths for the measurements of the device.

    Arguments:
        uid {str} -- Unique identifier of the device
        measurements {dict} -- Measurements of the device
    """
    base = ["0:Objects", "2:Device", "2:Measurements"]
    paths = {}
    for measurement in measurements:
        if measurements[measurement]["type"] == "voltage":
            valtypes = ["ULNComplexRe", "ULNComplexIm"]

            attributes = []
            if exist_and_true(measurements[measurement], "min"):
                attributes.append("Minimum")
            if exist_and_true(measurements[measurement], "max"):
                attributes.append("Maximum")

            for valtype in valtypes:
                for attribute in attributes:
                    paths[f"{uid}/{measurement}/{valtype}/{attribute}"] = (
                        base
                        + ["2:UG"]
                        + [f"2:{measurement}"]
                        + [f"2:{valtype}"]
                        + [f"2:{attribute}"]
                    )

                if measurements[measurement]["momentary"]:
                    paths[f"{uid}/{measurement}/{valtype}/Momentary"] = (
                        base + ["2:UG"] + [f"2:{measurement}"] + [f"2:{valtype}"]
                    )
        elif measurements[measurement]["type"] == "current":
            valtypes = ["IComplexIm", "IComplexRe"]

            attributes = []
            if exist_and_true(measurements[measurement], "min"):
                attributes.append("Minimum")
            if exist_and_true(measurements[measurement], "max"):
                attributes.append("Maximum")

            for valtype in valtypes:
                group, channel = measurement.split("/")
                for attribute in attributes:
                    paths[f"{uid}/{measurement}/{valtype}/{attribute}"] = (
                        base
                        # + [f"2:{measurement}"]
                        + [f"2:{group}"]
                        + [f"2:{channel}"]
                        + [f"2:{valtype}"]
                        + [f"2:{attribute}"]
                    )

        elif measurements[measurement]["type"] == "frequency":
            if exist_and_true(measurements[measurement], "min"):
                paths[f"{uid}/Freq/Minimum"] = (
                    base + ["2:UG"] + ["2:Freq"] + ["2:Minimum"]
                )
            if exist_and_true(measurements[measurement], "max"):
                paths[f"{uid}/Freq/Maximum"] = (
                    base + ["2:UG"] + ["2:Freq"] + ["2:Maximum"]
                )
            if exist_and_true(measurements[measurement], "momentary"):
                paths[f"{uid}/Freq/Momentary"] = base + ["2:UG"] + ["2:Freq"]

    return paths


async def read_and_print(name, node):
    """
    Read a value from a node and print it.

    Arguments:
        name {str} -- Name of the node
        node {Node} -- Node to read from
    """
    value = await node.read_value()
    print(f"{name}: {value}")


async def read_and_store(name, node, publishing_handler):
    value = await node.read_value()
    publishing_handler.values[name] = value


class PublishingHandler:
    """
    The PublishingHandler is used to handle the sending of data to the broker.
    """

    def __init__(self, values):
        self.values = values
        self.last_time = 0

    def send_values(self, time, rate):
        time_delta = time - self.last_time
        if time_delta > 1 / rate:
            print(self.values)
            self.last_time = time
        return time_delta


class SubscriptionHandler:
    """
    The SubscriptionHandler is used to handle the data that is received for the
    subscription.
    """

    def __init__(self, node_ids: dict, publish_handler: PublishingHandler):
        self.node_ids = node_ids
        self.counter = 0
        self.values = publish_handler.values

    def datachange_notification(self, node, val, data):
        # print(f"{self.node_ids[nodeid_to_string(node.nodeid)]}, {val}")
        self.values[self.node_ids[nodeid_to_string(node.nodeid)]] = val
        # self.counter += 1 # used for testing


class Mode(Enum):
    SUBSCRIBE = 1
    GATHER = 2


async def read_measurements(device, mode: Mode):
    """Create browse paths, onnect to the device and read the measurements at
    given sample rate.

    Arguments:
        device -- Device configuration
    """
    uid = device["uid"]
    uri = device["uri"]
    port = device["port"]

    url = f"opc.tcp://{uri}:{port}"
    print(f"Connecting to {url} ...")

    browse_paths = construct_browse_paths(uid, device["measurements"])
    values = dict.fromkeys(browse_paths.keys())

    pub_handler = PublishingHandler(values)
    # asyncio.run(pub_handler.send_values())

    async with Client(url=url) as client:
        nodes = {}
        node_ids = {}

        for measurement, browse_path in browse_paths.items():
            print(f"{measurement} : {browse_path}")
            nodes[measurement] = await client.nodes.root.get_child(browse_path)
            node_ids[nodeid_to_string(nodes[measurement].nodeid)] = measurement

        if mode == Mode.SUBSCRIBE:
            print("Reading in subscription mode ...")

            handler = SubscriptionHandler(node_ids, pub_handler)
            sub = await client.create_subscription(0, handler)

            await asyncio.gather(
                *[sub.subscribe_data_change(node) for _, node in nodes.items()]
            )
            while True:
                # pub_handler.send_values(time.time(), device["sending_rate"])
                time_delta = pub_handler.send_values(
                    time.time(), device["sending_rate"]
                )
                await asyncio.sleep(1 / device["sending_rate"] - time_delta)
            # await asyncio.sleep(float("inf"))

        elif mode == Mode.GATHER:
            print("Reading in gather mode ...")

            while True:
                await asyncio.gather(
                    # *[read_and_print(name, node) for name, node in nodes.items()]
                    *[
                        read_and_store(name, node, pub_handler)
                        for name, node in nodes.items()
                    ]
                )
                pub_handler.send_values(time.time(), device["sending_rate"])


def main():
    parser = argparse.ArgumentParser(
        description="Read measurements from UMG801 and print results to STDOUT."
    )
    parser.add_argument("CONFIG", type=str, help="Path to config file.")
    parser.add_argument(
        "--mode",
        "-m",
        metavar="MODE",
        type=str,
        nargs="?",
        default="SUBSCRIBE",
        choices=["SUBSCRIBE", "GATHER"],
        help="Mode to read measurements via OPC UA. Can be SUBSCRIBE or GATHER.",
    )
    args = parser.parse_args()

    print(args)

    conf = read_config(args.CONFIG, config_schema)
    mode = Mode[args.mode]

    for dev in conf["devices"]:
        asyncio.run(read_measurements(dev, mode))


if __name__ == "__main__":
    main()
