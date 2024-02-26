# SPDX-FileCopyrightText: 2023 Felix Wege, EONERC-ACS, RWTH Aachen University
# SPDX-License-Identifier: Apache-2.0
import sys


def log_msg(msg):
    """
    Log a message to STDERR.

    Arguments:
        msg {str} -- Message to log
    """
    print(msg, file=sys.stderr)
