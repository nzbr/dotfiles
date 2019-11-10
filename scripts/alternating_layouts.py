#!/usr/bin/env python

# This script is from:
# https://github.com/olemartinorg/i3-alternating-layout
#
# The MIT License (MIT)
#
# Copyright (c) 2013 Ole Martin Handeland
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import i3
import re
import subprocess
import getopt
import sys
import os


def find_parent(window_id):
    """
        Find the parent of a given window id
    """
    root_window = i3.get_tree()
    result = [None]

    def finder(n, p=None):
        if result[0] is not None:
            return
        for node in n:
            if node['id'] == window_id:
                result[0] = p
                return
            if len(node['nodes']):
                finder(node['nodes'], node)

    finder(root_window['nodes'])
    return result[0]


def set_layout():
    """
        Set the layout/split for the currently
        focused window to either vertical or
        horizontal, depending on its width/height
    """
    current_win = i3.filter(nodes=[], focused=True)
    for win in current_win:
        parent = find_parent(win['id'])

        if (parent and "rect" in parent
                   and parent['layout'] != 'tabbed'
                   and parent['layout'] != 'stacked'):
            height = parent['rect']['height']
            width = parent['rect']['width']

            if height > width:
                new_layout = 'vertical'
            else:
                new_layout = 'horizontal'

            i3.split(new_layout)


def print_help():
    print("Usage: " + sys.argv[0] + " [-p path/to/pid.file]")
    print("")
    print("Options:")
    print("    -p path/to/pid.file   Saves the PID for this program in the filename specified")
    print("")


def main():
    """
        Main function - listen for window focus
        changes and call set_layout when focus
        changes
    """
    opt_list, args = getopt.getopt(sys.argv[1:], 'hp:')
    pid_file = None
    for opt in opt_list:
        if opt[0] == "-h":
            print_help()
            sys.exit()
        if opt[0] == "-p":
            pid_file = opt[1]

    if pid_file:
        with open(pid_file, 'w') as f:
            f.write(str(os.getpid()))


    process = subprocess.Popen(
        ['xprop', '-root', '-spy'],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    regex = re.compile(b'^_NET_CLIENT_LIST_STACKING|^_NET_ACTIVE_WINDOW')

    last_line = ""
    while True:
        line = process.stdout.readline()
        if line == b'': #X is dead
            break
        if line == last_line:
            continue
        if regex.match(line):
            set_layout()
        last_line = line

    process.kill()
    sys.exit()

if __name__ == "__main__":
    main()
