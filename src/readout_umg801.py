# SPDX-FileCopyrightText: 2023 Felix Wege, EONERC-ACS, RWTH Aachen University
# SPDX-License-Identifier: Apache-2.0
import argparse
import asyncio

from config_parser import read_config
from logger import log_msg
from subscription_handler import Mode, read_measurements


if __name__ == "__main__":
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

    log_msg(args)

    conf = read_config(args.CONFIG)
    mode = Mode[args.mode]

    for dev in conf["devices"]:
        asyncio.run(read_measurements(dev, mode))
