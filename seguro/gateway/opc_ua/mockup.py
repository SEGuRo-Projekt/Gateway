# SPDX-FileCopyrightText: 2023 Felix Wege, EONERC-ACS, RWTH Aachen University
# SPDX-License-Identifier: Apache-2.0

import asyncio
import logging
import random
import sys
import argparse

from asyncua import Server


async def run_server(rate: float, endpoint: str, uri):
    _logger = logging.getLogger(__name__)
    server = Server()
    await server.init()
    server.set_endpoint(endpoint)
    server.set_server_name("OPC UA Mockup Measurement Device")

    idx = await server.register_namespace(uri)

    device = await server.nodes.objects.add_object(idx, "Device")
    measurements = await device.add_object(idx, "Measurement")

    # Voltages
    ug = await measurements.add_object(idx, "UG")

    variables = {}
    variables["freq"] = await ug.add_variable(idx, "Freq", 50.0)

    u1 = await ug.add_object(idx, "U1")
    variables["uln1_im"] = await u1.add_variable(idx, "ULNComplexIm", 0.0)
    variables["uln1_re"] = await u1.add_variable(idx, "ULNComplexRe", 0.0)

    u2 = await ug.add_object(idx, "U2")
    variables["uln2_im"] = await u2.add_variable(idx, "ULNComplexIm", 0.0)
    variables["uln2_re"] = await u2.add_variable(idx, "ULNComplexRe", 0.0)

    u3 = await ug.add_object(idx, "U3")
    variables["uln3_im"] = await u3.add_variable(idx, "ULNComplexIm", 0.0)
    variables["uln3_re"] = await u3.add_variable(idx, "ULNComplexRe", 0.0)

    # Currents
    ig1 = await measurements.add_object(idx, "IG1")
    ig1_i1 = await ig1.add_object(idx, "I1")
    variables["ig1_i1_im"] = await ig1_i1.add_variable(idx, "IComplexIm", 0.0)
    variables["ig1_i1_re"] = await ig1_i1.add_variable(idx, "IComplexRe", 0.0)

    ig1_i2 = await ig1.add_object(idx, "I2")
    variables["ig1_i2_im"] = await ig1_i2.add_variable(idx, "IComplexIm", 0.0)
    variables["ig1_i2_re"] = await ig1_i2.add_variable(idx, "IComplexRe", 0.0)

    ig1_i3 = await ig1.add_object(idx, "I3")
    variables["ig1_i3_im"] = await ig1_i3.add_variable(idx, "IComplexIm", 0.0)
    variables["ig1_i3_re"] = await ig1_i3.add_variable(idx, "IComplexRe", 0.0)

    # Module
    modules = await device.add_object(idx, "Modules")
    module1 = await modules.add_object(idx, "Module1")
    mod1_measurements = await module1.add_object(idx, "Measurements")
    mod1_ig1 = await mod1_measurements.add_object(idx, "IG1")
    mod1_ig1_i1 = await mod1_ig1.add_object(idx, "I1")
    variables["mod1_ig1_i1_im"] = await mod1_ig1_i1.add_variable(
        idx, "IComplexIm", 0.0
    )
    variables["mod1_ig1_i1_re"] = await mod1_ig1_i1.add_variable(
        idx, "IComplexRe", 0.0
    )

    mod1_ig1_i2 = await mod1_ig1.add_object(idx, "I2")
    variables["mod1_ig1_i2_im"] = await mod1_ig1_i2.add_variable(
        idx, "IComplexIm", 0.0
    )
    variables["mod1_ig1_i2_re"] = await mod1_ig1_i2.add_variable(
        idx, "IComplexRe", 0.0
    )

    mod1_ig1_i3 = await mod1_ig1.add_object(idx, "I3")
    variables["mod1_ig1_i3_im"] = await mod1_ig1_i3.add_variable(
        idx, "IComplexIm", 0.0
    )
    variables["mod1_ig1_i3_re"] = await mod1_ig1_i3.add_variable(
        idx, "IComplexRe", 0.0
    )

    mod1_ig2 = await mod1_measurements.add_object(idx, "IG2")
    mod1_ig2_i1 = await mod1_ig2.add_object(idx, "I1")
    variables["mod1_ig2_i1_im"] = await mod1_ig2_i1.add_variable(
        idx, "IComplexIm", 0.0
    )
    variables["mod1_ig2_i1_re"] = await mod1_ig2_i1.add_variable(
        idx, "IComplexRe", 0.0
    )
    mod1_ig2_i2 = await mod1_ig2.add_object(idx, "I2")
    variables["mod1_ig2_i2_im"] = await mod1_ig2_i2.add_variable(
        idx, "IComplexIm", 0.0
    )
    variables["mod1_ig2_i2_re"] = await mod1_ig2_i2.add_variable(
        idx, "IComplexRe", 0.0
    )

    mod1_ig2_i3 = await mod1_ig2.add_object(idx, "I3")
    variables["mod1_ig2_i3_im"] = await mod1_ig2_i3.add_variable(
        idx, "IComplexIm", 0.0
    )
    variables["mod1_ig2_i3_re"] = await mod1_ig2_i3.add_variable(
        idx, "IComplexRe", 0.0
    )

    for _, var in variables.items():
        await var.set_writable()

    _logger.info("Starting server!")

    async with server:
        while True:
            await asyncio.sleep(1 / rate)
            # Update variables with random values within realistic boundaries
            # Freq: 49.9 - 50.1 Hz
            # ULN: 227.0 - 235.0 V
            # IG: 0.0 - 1.15 A
            # Power factor: 0.95 - 1.0
            for var, obj in variables.items():
                if "freq" in var.lower():
                    await obj.write_value(random.uniform(49.9, 50.1))
                if "uln" in var.lower():
                    if "im" in var.lower():
                        await obj.write_value(random.uniform(0.0, 11.5))
                    if "re" in var.lower():
                        await obj.write_value(random.uniform(227.0, 235.0))
                if "ig" in var.lower():
                    if "im" in var.lower():
                        await obj.write_value(random.uniform(0.0, 1.15))
                    if "re" in var.lower():
                        await obj.write_value(random.uniform(22.7, 23.5))


def main() -> int:
    logging.basicConfig(level=logging.DEBUG)

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--uri",
        "-u",
        type=str,
        default="https://github.com/SEGuRo-Projekt/Gateway",
    )
    parser.add_argument("--rate", "-r", type=float, default=1.0)
    parser.add_argument(
        "--endpoint", "-e", type=str, default="opc.tcp://0.0.0.0:4840/"
    )

    args = parser.parse_args()

    asyncio.run(run_server(args.rate, args.endpoint, args.uri))

    return 0


if __name__ == "__main__":
    sys.exit(main())
