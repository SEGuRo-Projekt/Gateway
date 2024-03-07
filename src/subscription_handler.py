# SPDX-FileCopyrightText: 2023 Felix Wege, EONERC-ACS, RWTH Aachen University
# SPDX-License-Identifier: Apache-2.0
import asyncio
import time

from enum import Enum
from asyncua import Client

from config_parser import Type, opcua_objects
from publishing_handler import PublishingHandler
from logger import log_msg


class Mode(Enum):
    """
    Enum for the different modes of reading the measurements.
    """

    SUBSCRIBE = 1
    GATHER = 2


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

    for measurement, attributes in measurements.items():
        if opcua_objects[measurement] == Type.VOLTAGE:

            valtypes = ["ULNComplexRe", "ULNComplexIm"]
            for attribute in attributes:
                for valtype in valtypes:
                    if attribute == "Momentary":
                        paths[f"{uid}/{measurement}/{valtype}/Momentary"] = (
                            base + ["2:UG"] + [f"2:{measurement}"] + [f"2:{valtype}"]
                        )
                    else:
                        paths[f"{uid}/{measurement}/{valtype}/{attribute}"] = (
                            base
                            + ["2:UG"]
                            + [f"2:{measurement}"]
                            + [f"2:{valtype}"]
                            + [f"2:{attribute}"]
                        )

        elif opcua_objects[measurement] == Type.CURRENT:
            valtypes = ["IComplexRe", "IComplexIm"]
            for attribute in attributes:
                # for attribute in attributes:
                group, channel = measurement.split("_")
                for valtype in valtypes:
                    if attribute == "Momentary":
                        paths[f"{uid}/{measurement}/{valtype}/Momentary"] = (
                            base + [f"2:{group}"] + [f"2:{channel}"] + [f"2:{valtype}"]
                        )
                    else:
                        paths[f"{uid}/{measurement}/{valtype}/{attribute}"] = (
                            base
                            + [f"2:{group}"]
                            + [f"2:{channel}"]
                            + [f"2:{valtype}"]
                            + [f"2:{attribute}"]
                        )

        elif opcua_objects[measurement] == Type.FREQUENCY:
            for attribute in attributes:
                if attribute == "Momentary":
                    paths[f"{uid}/Freq/Momentary"] = base + ["2:UG"] + ["2:Freq"]
                else:
                    paths[f"{uid}/Freq/{attribute}"] = (
                        base + ["2:UG"] + ["2:Freq"] + [f"2:{attribute}"]
                    )

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
    """
    Read a value from a node and store it in the publishing handler.

    Arguments:
        name {str} -- Name of the node, used as dict key
        node {Node} -- Node to read from
        publishing_handler {PublishingHandler} -- Publishing handler to store the value
    """
    value = await node.read_value()
    publishing_handler.values[name] = value


async def read_measurements(device, opcua_ids, mode: Mode):
    """Create browse paths, onnect to the device and read the measurements at
    given sample rate.

    Arguments:
        device -- Device configuration
    """
    uid = device["uid"]
    uri = device["uri"]
    port = device["port"]

    url = f"opc.tcp://{uri}:{port}"
    log_msg(f"Connecting to {url} ...")

    browse_paths = construct_browse_paths(uid, opcua_ids)
    values = dict.fromkeys(browse_paths.keys())

    log_msg(f"Browse paths: {browse_paths}")

    pub_handler = PublishingHandler(values)

    async with Client(url=url) as client:
        nodes = {}
        node_ids = {}

        for measurement, browse_path in browse_paths.items():
            nodes[measurement] = await client.nodes.root.get_child(browse_path)
            node_ids[nodeid_to_string(nodes[measurement].nodeid)] = measurement

        if mode == Mode.SUBSCRIBE:
            log_msg("Reading in subscription mode ...")

            handler = SubscriptionHandler(node_ids, pub_handler)
            sub = await client.create_subscription(0, handler)

            await asyncio.gather(
                *[sub.subscribe_data_change(node) for _, node in nodes.items()]
            )

            while True:
                time_delta = pub_handler.send_values(
                    time.time(), device["sending_rate"]
                )
                # Wait until the next sending time to avoid busy waiting
                await asyncio.sleep(1 / device["sending_rate"] - time_delta)

        elif mode == Mode.GATHER:
            log_msg("Reading in gather mode ...")

            while True:
                await asyncio.gather(
                    *[
                        read_and_store(name, node, pub_handler)
                        for name, node in nodes.items()
                    ]
                )
                pub_handler.send_values(time.time(), device["sending_rate"])


<<<<<<<< HEAD:seguro/gateway/readout_umg801.py
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
========
class SubscriptionHandler:
    """
    The SubscriptionHandler is used to handle the data that is received for the
    subscription.
    """
>>>>>>>> d8db7a0 (WIP: refactor code into multiple modules):src/subscription_handler.py

    def __init__(self, node_ids: dict, publish_handler: PublishingHandler):
        self.node_ids = node_ids
        self.counter = 0
        self.values = publish_handler.values

<<<<<<<< HEAD:seguro/gateway/readout_umg801.py
    conf = read_config(args.CONFIG, config_schema)
    mode = Mode[args.mode]

    for dev in conf["devices"]:
        asyncio.run(read_measurements(dev, mode))


if __name__ == "__main__":
    main()
========
    def datachange_notification(self, node, val, data):
        """
        Callback for the data change notification. Stores updated values in the
        values dict.
        """
        self.values[self.node_ids[nodeid_to_string(node.nodeid)]] = val
>>>>>>>> d8db7a0 (WIP: refactor code into multiple modules):src/subscription_handler.py
