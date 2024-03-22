# SPDX-FileCopyrightText: 2023 Felix Wege, EONERC-ACS, RWTH Aachen University
# SPDX-License-Identifier: Apache-2.0

import time


class PublishingHandler:
    """
    The PublishingHandler is used to handle the sending of data to the broker.
    """

    def __init__(self, values):
        self.values = values
        self.last_time = 0

    def __reduce_complex(self, values):
        """
        Reduce complex values to a single value.
        """
        reduced_complex = {}
        for key, value in values.items():
            if "Re" in key:
                reduced_complex[key.replace("Re", "")] = str(value)
            elif "Im" in key:
                if str(value).startswith("-"):
                    reduced_complex[key.replace("Im", "")] += str(value) + "i"
                else:
                    reduced_complex[key.replace("Im", "")] += (
                        "+" + str(value) + "i"
                    )
            else:
                reduced_complex[key] = value
        return reduced_complex

    def send_values(self, _time, rate):
        """
        Send values to broker if the time delta is greater than the sending
        rate.

        Convert data to string in the villas.human format and print
        it to STDOUT to be captured by an exec-type VILLASnode.

        Arguments:
            _time {float} -- Current time
            rate {float} -- Sending rate in Hz

        Returns:
            float -- Time delta to the last sending
        """
        time_delta = _time - self.last_time
        if None in self.values.values():
            # If there are still None values, do not send anything
            return time_delta

        if time_delta > 1 / rate:
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

            self.last_time = _time
        return time_delta
