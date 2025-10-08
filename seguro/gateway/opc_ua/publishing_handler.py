# SPDX-FileCopyrightText: 2023 Felix Wege, EONERC-ACS, RWTH Aachen University
# SPDX-License-Identifier: Apache-2.0

import time


class PublishingHandler:
    """
    The PublishingHandler is used to handle the sending of data to the broker.
    """

    def __init__(self, values):
        self.values = values
        self.next_time = -1
        self.synchronized = False

    def __reduce_complex(self, values):
        """
        Reduce complex values to a single value.
        """
        reduced_complex = {}
        for key, value in values.items():
            if (
                "Im" in key
                and reduced_complex.get(key.replace("Im", "Re")) is not None
            ):
                if str(value).startswith("-"):
                    reduced_complex[key.replace("Im", "")] = (
                        str(reduced_complex[key.replace("Im", "Re")])
                        + str(value)
                        + "i"
                    )
                else:
                    reduced_complex[key.replace("Im", "")] = (
                        str(reduced_complex[key.replace("Im", "Re")])
                        + "+"
                        + str(value)
                        + "i"
                    )
                del reduced_complex[key.replace("Im", "Re")]
            else:
                reduced_complex[key] = value
        return reduced_complex

    def send_values(self, rate):
        """
        Send values to broker if the time delta is greater than the sending
        rate.

        Convert data to string in the villas.human format and print
        it to STDOUT to be captured by an exec-type VILLASnode.

        Arguments:
            rate {float} -- Sending rate in Hz

        Returns:
            float -- Time to sleep until next interval
        """
        interval = 1 / rate

        if None in self.values.values():
            # If there are still None values, do not send anything
            return -1

        if not self.synchronized:
            # Busy wait until the next aligned interval
            _time = time.time()
            while _time % interval > interval * 0.01:
                _time = time.time()

            self.synchronized = True
            self.next_time = _time - _time % interval  # Inverse modulo

        if time.time() >= self.next_time:
            # Print the values to STDOUT in the villas.human format:
            # {timestamp_s}.{timestamp_ns} {value1} {value2} ...
            reduced_values = self.__reduce_complex(self.values)
            epoch_time = time.time_ns()
            epoch_s = str(epoch_time // 1_000_000_000)
            epoch_ns = str(epoch_time % 1_000_000_000).zfill(9)
            print(f"{epoch_s}.{epoch_ns}", end=" ")

            print(
                " ".join(str(x) for x in list(reduced_values.values())),
                flush=True,
            )
            self.next_time += 1 / rate

        # Compensate for drift introduced by the function itself
        drift = time.time() % interval
        return interval - drift
