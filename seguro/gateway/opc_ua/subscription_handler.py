# SPDX-FileCopyrightText: 2023 Felix Wege, EONERC-ACS, RWTH Aachen University
# SPDX-License-Identifier: Apache-2.0
import asyncio
import time

from enum import Enum
from asyncua import Client

from seguro.gateway.opc_ua.config_parser import Type, opcua_objects
from seguro.gateway.opc_ua.publishing_handler import PublishingHandler
from seguro.gateway.opc_ua.logger import log_msg


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
    paths = {}

    for measurement, attributes in measurements.items():
        base = ["0:Objects", "2:Device", "2:Measurements"]

        if opcua_objects.get(measurement) == Type.VOLTAGE:

            valtypes = ["ULNComplexRe", "ULNComplexIm"]
            for attribute in attributes:
                for valtype in valtypes:
                    if attribute == "Momentary":
                        paths[f"{uid}/{measurement}/{valtype}/Momentary"] = (
                            base
                            + ["2:UG"]
                            + [f"2:{measurement}"]
                            + [f"2:{valtype}"]
                        )
                    else:
                        paths[f"{uid}/{measurement}/{valtype}/{attribute}"] = (
                            base
                            + ["2:UG"]
                            + [f"2:{measurement}"]
                            + [f"2:{valtype}"]
                            + [f"2:{attribute}"]
                        )

        elif opcua_objects.get(measurement) == Type.CURRENT:
            valtypes = ["IComplexRe", "IComplexIm"]
            for attribute in attributes:

                keywords = measurement.split("_")
                module = None
                if len(keywords) == 3:
                    module, group, channel = keywords
                    base = [
                        "0:Objects",
                        "2:Device",
                        "2:Modules",
                        f"2:{module}",
                        "2:Measurements",
                    ]
                elif len(keywords) == 2:
                    group, channel = keywords

                else:
                    raise ValueError(
                        "Allowed current measurement forms: IGx_Iy or Modulez_IGx_Iy"
                    )

                for valtype in valtypes:
                    if attribute == "Momentary":
                        paths[f"{uid}/{measurement}/{valtype}/Momentary"] = (
                            base
                            + [f"2:{group}"]
                            + [f"2:{channel}"]
                            + [f"2:{valtype}"]
                        )
                    else:
                        paths[f"{uid}/{measurement}/{valtype}/{attribute}"] = (
                            base
                            + [f"2:{group}"]
                            + [f"2:{channel}"]
                            + [f"2:{valtype}"]
                            + [f"2:{attribute}"]
                        )

        elif opcua_objects.get(measurement) == Type.POWER:
            valtypes = [("PowerComplexRe", "P"), ("PowerComplexIm", "Q")]
            for attribute in attributes:
                module = None
                # group, channel, _ = measurement.split("_")

                keywords = measurement.split("_")
                module = None
                if len(keywords) == 4:
                    module, group, channel, _ = keywords
                    base = [
                        "0:Objects",
                        "2:Device",
                        "2:Modules",
                        f"2:{module}",
                        "2:Measurements",
                    ]
                elif len(keywords) == 3:
                    group, channel, _ = keywords

                else:
                    raise ValueError(
                        (
                            "Allowed power measurement forms: IGx_Iy_Power or "
                            "Modulez_IGx_Iy_Power"
                        )
                    )

                for valtype in valtypes:
                    if attribute == "Momentary":
                        paths[
                            f"{uid}/{measurement}/{valtype[0]}/Momentary"
                        ] = (
                            base
                            + [f"2:{group}"]
                            + [f"2:{channel}"]
                            + [f"2:{valtype[1]}"]
                        )
                    else:
                        paths[
                            f"{uid}/{measurement}/{valtype[0]}/{attribute}"
                        ] = (
                            base
                            + [f"2:{group}"]
                            + [f"2:{channel}"]
                            + [f"2:{valtype}"]
                            + [f"2:{attribute[1]}"]
                        )

        elif opcua_objects.get(measurement) == Type.FREQUENCY:
            for attribute in attributes:
                if attribute == "Momentary":
                    paths[f"{uid}/Freq/Momentary"] = (
                        base + ["2:UG"] + ["2:Freq"]
                    )
                else:
                    paths[f"{uid}/Freq/{attribute}"] = (
                        base + ["2:UG"] + ["2:Freq"] + [f"2:{attribute}"]
                    )

        else:
            paths[measurement] = measurement.split(",")
            log_msg(
                "Measurement object not recognized, "
                + f"interpreting as browse path {paths[measurement]}..."
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


async def connect_and_publish(
    url: str, device: dict, browse_paths: dict, mode: Mode
):
    values = dict.fromkeys(browse_paths.keys())
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
                await client.check_connection()

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


async def read_measurements(device, opcua_objs, mode: Mode):
    """Create browse paths, connect to the device and read/publish the measurements at
    given sample rate.

    Arguments:
        device -- Device configuration
    """
    uid = device["uid"]
    uri = device["uri"]
    port = device["port"]

    url = f"opc.tcp://{uri}:{port}"
    log_msg(f"Connecting to {url} ...")

    browse_paths = construct_browse_paths(uid, opcua_objs)
    log_msg(f"Browse paths: {browse_paths}")

    backoff_duration = 1
    while True:
        try:
            await connect_and_publish(url, device, browse_paths, mode)

        except Exception as e:
            log_msg(f"Exception in read_measurements: {e}")
            log_msg(
                f"Trying to re-establish connection in {backoff_duration} second..."
            )

            await asyncio.sleep(backoff_duration)
            backoff_duration = min(
                backoff_duration * 2, 600
            )  # Exponential backoff, max 10 minutes


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
        """
        Callback for the data change notification. Stores updated values in the
        values dict.
        """
        self.values[self.node_ids[nodeid_to_string(node.nodeid)]] = val
